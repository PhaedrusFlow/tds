#Requires -Version 5.1
<#
.SYNOPSIS
    Installs as much of qompassai/dotfiles as is practical on Windows through
    MSYS2 + pacman, from PowerShell.

.DESCRIPTION
    - Bootstraps MSYS2 if necessary.
    - Uses UCRT64 on x64 Windows and CLANGARM64 on ARM64 Windows by default.
    - Fully upgrades MSYS2 before installing packages.
    - Resolves package names against the currently configured MSYS2 repositories.
    - Pulls the current x86_64-linux package list from qompassai/dotfiles/flake.nix
      for the Full profile, then installs only packages with a safe MSYS2 match.
    - Adds a curated Windows/MSYS2 developer set for Neovim, shells, compilers,
      language runtimes, linters, formatters, databases, networking, and media.
    - Skips Linux-only packages instead of failing the entire run.
    - Writes a JSON report of resolved, skipped, and failed packages.

    The script deliberately prefers native MinGW/UCRT or Clang packages over
    MSYS-runtime packages. MSYS packages are used only for a curated set of
    Unix-like tools where that is intentional.

.EXAMPLE
    .\install-qompass-msys2.ps1

.EXAMPLE
    .\install-qompass-msys2.ps1 -Profile Dev

.EXAMPLE
    .\install-qompass-msys2.ps1 -Profile Full -SkipSystemUpgrade

.EXAMPLE
    .\install-qompass-msys2.ps1 -Profile Full -DryRun

.EXAMPLE
    .\install-qompass-msys2.ps1 -AddToUserPath:$false
#>

[CmdletBinding()]
param(
    [ValidateSet('Core', 'Dev', 'Full')]
    [string] $Profile = 'Full',

    [ValidateSet('UCRT64', 'CLANG64', 'CLANGARM64')]
    [string] $MsysEnvironment = 'UCRT64',

    [string] $MsysRoot = 'C:\msys64',

    [bool] $BootstrapMsys2 = $true,

    [bool] $AddToUserPath = $true,

    [switch] $AddMsysUsrBinToUserPath,

    [switch] $SkipSystemUpgrade,

    [switch] $SkipRepoPackageDiscovery,

    [switch] $DryRun
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 can otherwise inherit legacy TLS defaults.
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}
catch {
    # PowerShell 7+ generally uses the OS TLS stack directly.
}

$RepoFlakeUrl = 'https://raw.githubusercontent.com/qompassai/dotfiles/main/flake.nix'
$RepoTreeUrl = 'https://api.github.com/repos/qompassai/dotfiles/git/trees/main?recursive=1'

function Write-Section {
    param([Parameter(Mandatory)][string] $Message)
    Write-Host ''
    Write-Host ('=' * 78) -ForegroundColor DarkGray
    Write-Host $Message -ForegroundColor Cyan
    Write-Host ('=' * 78) -ForegroundColor DarkGray
}

function Write-Info {
    param([Parameter(Mandatory)][string] $Message)
    Write-Host "[INFO] $Message" -ForegroundColor Gray
}

function Write-Ok {
    param([Parameter(Mandatory)][string] $Message)
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([Parameter(Mandatory)][string] $Message)
    Write-Warning $Message
}

function Get-WindowsArchitecture {
    $arch = $null

    try {
        $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    }
    catch {
        $arch = $env:PROCESSOR_ARCHITEW6432
        if ([string]::IsNullOrWhiteSpace($arch)) {
            $arch = $env:PROCESSOR_ARCHITECTURE
        }
    }

    switch -Regex ($arch) {
        'ARM64|Arm64' { return 'arm64' }
        'AMD64|X64|x64' { return 'x64' }
        default { throw "Unsupported Windows architecture: $arch" }
    }
}

function Get-EnvironmentMetadata {
    param([Parameter(Mandatory)][string] $Name)

    switch ($Name) {
        'UCRT64' {
            return [pscustomobject]@{
                Prefix = 'mingw-w64-ucrt-x86_64'
                BinDir = 'ucrt64'
                ShellSwitch = '-ucrt64'
            }
        }
        'CLANG64' {
            return [pscustomobject]@{
                Prefix = 'mingw-w64-clang-x86_64'
                BinDir = 'clang64'
                ShellSwitch = '-clang64'
            }
        }
        'CLANGARM64' {
            return [pscustomobject]@{
                Prefix = 'mingw-w64-clang-aarch64'
                BinDir = 'clangarm64'
                ShellSwitch = '-clangarm64'
            }
        }
        default {
            throw "Unsupported MSYS2 environment: $Name"
        }
    }
}

function Find-Msys2Root {
    param([Parameter(Mandatory)][string] $PreferredRoot)

    $roots = New-Object System.Collections.Generic.List[string]
    [void] $roots.Add($PreferredRoot)

    if ($PreferredRoot -ne 'C:\msys64') {
        [void] $roots.Add('C:\msys64')
    }

    $pacmanCommand = Get-Command pacman.exe -ErrorAction SilentlyContinue
    if ($null -ne $pacmanCommand) {
        $bin = Split-Path -Parent $pacmanCommand.Source
        $usr = Split-Path -Parent $bin
        $detectedRoot = Split-Path -Parent $usr
        if (-not [string]::IsNullOrWhiteSpace($detectedRoot)) {
            [void] $roots.Add($detectedRoot)
        }
    }

    foreach ($root in $roots | Select-Object -Unique) {
        if (Test-Path -LiteralPath (Join-Path $root 'usr\bin\bash.exe')) {
            return $root
        }
    }

    return $PreferredRoot
}

function Install-Msys2 {
    param(
        [Parameter(Mandatory)][string] $TargetRoot,
        [Parameter(Mandatory)][ValidateSet('x64', 'arm64')][string] $Architecture
    )

    if ($DryRun) {
        Write-Info "DRY RUN: would install MSYS2 to $TargetRoot"
        return
    }

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($null -ne $winget) {
        Write-Info 'Bootstrapping MSYS2 with WinGet (package MSYS2.MSYS2).'

        $arguments = @(
            'install',
            '--id', 'MSYS2.MSYS2',
            '--exact',
            '--source', 'winget',
            '--accept-package-agreements',
            '--accept-source-agreements',
            '--silent',
            '--location', $TargetRoot
        )

        & $winget.Source @arguments
        $wingetExit = $LASTEXITCODE

        # Some installer return codes mean that installation is still being
        # finalized. Check for a usable bash.exe regardless of the exact code.
        for ($attempt = 0; $attempt -lt 60; $attempt++) {
            if (Test-Path -LiteralPath (Join-Path $TargetRoot 'usr\bin\bash.exe')) {
                return
            }

            if (Test-Path -LiteralPath 'C:\msys64\usr\bin\bash.exe') {
                return
            }

            Start-Sleep -Seconds 2
        }

        Write-Warn "WinGet exited with code $wingetExit but did not leave a usable MSYS2 install; using the verified pinned installer fallback."
    }

    # Current stable MSYS2 installer as of 2026-09-21.
    # The SHA-256 values are from Microsoft's WinGet manifest for MSYS2 20260611.
    if ($Architecture -eq 'arm64') {
        $installerUrl = 'https://github.com/msys2/msys2-installer/releases/download/2026-06-11/msys2-arm64-20260611.exe'
        $expectedHash = '6E29F2A62A7BEB9181B14FA4A72A920527726E4F5C366FD13F5DF36AE82600C4'
    }
    else {
        $installerUrl = 'https://github.com/msys2/msys2-installer/releases/download/2026-06-11/msys2-x86_64-20260611.exe'
        $expectedHash = '3150D7D9AA5DEDD900A7F52300D4D918271E3A8FC47DE94848818FD5A430E6B0'
    }

    $installerPath = Join-Path ([System.IO.Path]::GetTempPath()) ('msys2-installer-' + [Guid]::NewGuid().ToString('N') + '.exe')

    try {
        Write-Info "Downloading the pinned MSYS2 20260611 installer from the official release."
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

        $actualHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
        if ($actualHash -ne $expectedHash) {
            throw "MSYS2 installer SHA-256 mismatch. Expected $expectedHash but received $actualHash."
        }

        Write-Ok 'MSYS2 installer SHA-256 verified.'

        $rootForInstaller = $TargetRoot -replace '\\', '/'
        & $installerPath 'install' '--confirm-command' '--accept-messages' '--root' $rootForInstaller

        if ($LASTEXITCODE -ne 0) {
            throw "MSYS2 installer exited with code $LASTEXITCODE."
        }
    }
    finally {
        Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
    }
}

$WindowsArchitecture = Get-WindowsArchitecture

if (-not $PSBoundParameters.ContainsKey('MsysEnvironment')) {
    if ($WindowsArchitecture -eq 'arm64') {
        $MsysEnvironment = 'CLANGARM64'
    }
    else {
        $MsysEnvironment = 'UCRT64'
    }
}

if ($WindowsArchitecture -eq 'x64' -and $MsysEnvironment -eq 'CLANGARM64') {
    throw 'CLANGARM64 cannot be used on x64 Windows.'
}

$MsysRoot = Find-Msys2Root -PreferredRoot $MsysRoot
$EnvironmentMetadata = Get-EnvironmentMetadata -Name $MsysEnvironment
$PackagePrefix = $EnvironmentMetadata.Prefix
$MingwBin = Join-Path $MsysRoot ($EnvironmentMetadata.BinDir + '\bin')
$MsysUsrBin = Join-Path $MsysRoot 'usr\bin'
$Bash = Join-Path $MsysUsrBin 'bash.exe'

Write-Section 'MSYS2 bootstrap'

if (-not (Test-Path -LiteralPath $Bash)) {
    if (-not $BootstrapMsys2) {
        throw "MSYS2 was not found at $MsysRoot and -BootstrapMsys2 is disabled."
    }

    Install-Msys2 -TargetRoot $MsysRoot -Architecture $WindowsArchitecture

    # Re-detect in case WinGet used its canonical C:\msys64 location.
    $MsysRoot = Find-Msys2Root -PreferredRoot $MsysRoot
    $MingwBin = Join-Path $MsysRoot ($EnvironmentMetadata.BinDir + '\bin')
    $MsysUsrBin = Join-Path $MsysRoot 'usr\bin'
    $Bash = Join-Path $MsysUsrBin 'bash.exe'
}

if (-not $DryRun -and -not (Test-Path -LiteralPath $Bash)) {
    throw "MSYS2 bootstrap completed without creating $Bash."
}

if ($DryRun -and -not (Test-Path -LiteralPath $Bash)) {
    Write-Info 'DRY RUN: MSYS2 is not installed, so repository/package resolution will be estimated only.'
}

Write-Info "Windows architecture : $WindowsArchitecture"
Write-Info "MSYS2 root          : $MsysRoot"
Write-Info "MSYS2 environment   : $MsysEnvironment"
Write-Info "Package prefix      : $PackagePrefix"

function Invoke-Msys2 {
    param(
        [Parameter(Mandatory)][string] $Command,
        [switch] $Capture,
        [switch] $AllowFailure
    )

    if ($DryRun -and -not (Test-Path -LiteralPath $Bash)) {
        if ($Capture) {
            return @()
        }
        Write-Info "DRY RUN: $Command"
        return
    }

    $oldMsystem = $env:MSYSTEM
    $oldChere = $env:CHERE_INVOKING
    $oldNoPathConv = $env:MSYS2_ARG_CONV_EXCL

    try {
        $env:MSYSTEM = $MsysEnvironment
        $env:CHERE_INVOKING = '1'
        $env:MSYS2_ARG_CONV_EXCL = '*'

        if ($Capture) {
            $output = @(& $Bash -lc $Command)
        }
        else {
            & $Bash -lc $Command
            $output = @()
        }

        $exitCode = $LASTEXITCODE
    }
    finally {
        $env:MSYSTEM = $oldMsystem
        $env:CHERE_INVOKING = $oldChere
        $env:MSYS2_ARG_CONV_EXCL = $oldNoPathConv
    }

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "MSYS2 command failed with exit code ${exitCode}: $Command"
    }

    if ($Capture) {
        return $output
    }
}

function ConvertTo-BashLiteral {
    param([Parameter(Mandatory)][string] $Value)

    if ($Value -notmatch '^[A-Za-z0-9][A-Za-z0-9+_.:-]*$') {
        throw "Refusing to pass an unsafe package token to bash: $Value"
    }

    return "'" + $Value + "'"
}

if (-not $SkipSystemUpgrade -and -not $DryRun) {
    Write-Section 'Updating MSYS2'

    Write-Info 'Running the first full pacman upgrade pass.'
    Invoke-Msys2 -Command 'pacman --noconfirm -Syu' -AllowFailure

    Write-Info 'Running the second full pacman upgrade pass.'
    Invoke-Msys2 -Command 'pacman --noconfirm -Syu' -AllowFailure

    Write-Ok 'MSYS2 update passes completed.'
}
elseif ($SkipSystemUpgrade) {
    Write-Warn 'System upgrade was skipped. MSYS2 is a rolling distribution; partial upgrades are unsupported.'
}

function Get-QompassConfigDirectoryNames {
    if ($SkipRepoPackageDiscovery) {
        return @()
    }

    try {
        Write-Info "Reading .config directory names from $RepoTreeUrl"

        $headers = @{
            'User-Agent' = 'qompass-msys2-bootstrap'
            'Accept' = 'application/vnd.github+json'
        }

        $response = Invoke-RestMethod -Uri $RepoTreeUrl -Headers $headers
        $result = New-Object System.Collections.Generic.List[string]

        foreach ($entry in @($response.tree)) {
            $repoPath = [string] $entry.path

            if (-not $repoPath.StartsWith('.config/')) {
                continue
            }

            $relative = $repoPath.Substring('.config/'.Length)
            $firstSegment = ($relative -split '/')[0]

            if ($firstSegment -match '^[A-Za-z0-9][A-Za-z0-9+_.-]*$') {
                [void] $result.Add($firstSegment)
            }
        }

        return @($result | Sort-Object -Unique)
    }
    catch {
        Write-Warn "Could not read the repository .config tree: $($_.Exception.Message)"
        return @()
    }
}

function Get-QompassRepoPackages {
    if ($SkipRepoPackageDiscovery) {
        return @()
    }

    try {
        Write-Info "Reading package names from $RepoFlakeUrl"
        $response = Invoke-WebRequest -Uri $RepoFlakeUrl -UseBasicParsing
        $content = [string] $response.Content

        $pattern = '(?s)x86_64-linux\s*=\s*.*?paths\s*=\s*with\s+pkgs;\s*\[(?<body>.*?)\];'
        $match = [regex]::Match($content, $pattern)

        if (-not $match.Success) {
            Write-Warn 'Could not locate the x86_64-linux paths list in flake.nix.'
            return @()
        }

        $result = New-Object System.Collections.Generic.List[string]

        foreach ($line in ($match.Groups['body'].Value -split "`r?`n")) {
            $name = ($line -replace '#.*$', '').Trim()

            if ($name -match '^[A-Za-z0-9][A-Za-z0-9+_.-]*$') {
                [void] $result.Add($name)
            }
        }

        return @($result | Sort-Object -Unique)
    }
    catch {
        Write-Warn "Could not read the repository flake package list: $($_.Exception.Message)"
        return @()
    }
}

# Packages intentionally allowed to fall back to the MSYS repository if a
# native UCRT/Clang build is not available. This avoids accidentally installing
# an unrelated same-named MSYS package discovered from a Linux-only flake entry.
$MsysFallbackAllowlist = @(
    'bash',
    'bc',
    'bison',
    'byobu',
    'coreutils',
    'diffutils',
    'file',
    'findutils',
    'fish',
    'flex',
    'gawk',
    'git',
    'gnupg',
    'grep',
    'gzip',
    'less',
    'make',
    'man-db',
    'nano',
    'openssh',
    'patch',
    'rsync',
    'sed',
    'tar',
    'tmux',
    'tree',
    'unzip',
    'vim',
    'wget',
    'which',
    'xz',
    'zip',
    'zsh',
    'zstd'
)

$CorePackages = @(
    'bash',
    'bat',
    'btop',
    'coreutils',
    'curl',
    'delta',
    'editorconfig',
    'fastfetch',
    'fd',
    'file',
    'findutils',
    'fish',
    'fzf',
    'gawk',
    'gh',
    'git',
    'git-lfs',
    'github-cli',
    'gnupg',
    'grep',
    'jq',
    'lazygit',
    'less',
    'make',
    'nano',
    'neovim',
    'openssh',
    'p7zip',
    'ripgrep',
    'rsync',
    'sed',
    'starship',
    'tar',
    'tmux',
    'tree',
    'unzip',
    'vim',
    'wget',
    'which',
    'xz',
    'yq',
    'zip',
    'zsh',
    'zstd'
)

$DevPackages = @(
    'ant',
    'basedpyright',
    'biome',
    'ccache',
    'clang',
    'clang-tools-extra',
    'cmake',
    'composer',
    'gdb',
    'go',
    'gopls',
    'gradle',
    'java-jdk',
    'jdk-openjdk',
    'julia',
    'jupyter',
    'lld',
    'lldb',
    'llvm',
    'lua',
    'lua-language-server',
    'luajit',
    'luarocks',
    'maven',
    'meson',
    'ninja',
    'nodejs',
    'npm',
    'openjdk',
    'perl',
    'php',
    'pkgconf',
    'pre-commit',
    'python',
    'python-ipython',
    'python-jupyterlab',
    'python-pip',
    'python3',
    'ruby',
    'ruff',
    'rust',
    'rustup',
    'sccache',
    'shellcheck',
    'shfmt',
    'stylua',
    'taplo',
    'tree-sitter',
    'tree-sitter-cli',
    'yaml-language-server',
    'zls'
)

$FullExtras = @(
    # Directly represented in qonfig.yaml / common dotfile paths.
    'gh-dash',
    'ghostty',
    'kitty',
    'neovide',
    'sesh',
    'wezterm',
    'zed',

    # Data / services.
    'caddy',
    'mariadb',
    'nginx',
    'postgresql',
    'sqlite',
    'sqlite3',

    # Graphics / media / development applications.
    'audacity',
    'blender',
    'ffmpeg',
    'ghidra',
    'gimp',
    'godot',
    'imagemagick',
    'imagemagick-7',
    'inkscape',

    # Networking / security utilities.
    'age',
    'aria2',
    'clamav',
    'gnutls',
    'john',
    'openssl',
    'wireguard',
    'wireguard-tools'
)

# Aliases are base package names. The resolver tries the active MinGW/Clang
# prefix first, then (only where explicitly permitted) the MSYS package name.
$Aliases = @{
    'cargo'                = @('rust', 'rustup')
    'delta'                = @('git-delta', 'delta')
    'gh'                   = @('github-cli', 'gh')
    'github'               = @('github-cli')
    'gtk-2'                = @('gtk2')
    'gtk-3'                = @('gtk3')
    'gtk-4'                = @('gtk4')
    'imagemagick-7'        = @('imagemagick')
    'ipython'              = @('python-ipython')
    'java-jdk'             = @('openjdk', 'jdk-openjdk')
    'jupyter'              = @('python-jupyterlab', 'jupyterlab', 'jupyter')
    'neovim-nightly'       = @('neovim')
    'nvim'                 = @('neovim')
    'python3'              = @('python')
    'sqlite'               = @('sqlite3')
    'tree-sitter-cli'      = @('tree-sitter')
    'yaml-language-server' = @('yaml-language-server', 'nodejs-yaml-language-server')
    'wireguard'            = @('wireguard-tools')
}

$RepoPackages = @()
$ConfigDirectoryNames = @()

if ($Profile -eq 'Full') {
    $RepoPackages = Get-QompassRepoPackages
    $ConfigDirectoryNames = Get-QompassConfigDirectoryNames
}

$LogicalPackages = New-Object System.Collections.Generic.List[string]

foreach ($name in $CorePackages) {
    [void] $LogicalPackages.Add($name)
}

if ($Profile -in @('Dev', 'Full')) {
    foreach ($name in $DevPackages) {
        [void] $LogicalPackages.Add($name)
    }
}

if ($Profile -eq 'Full') {
    foreach ($name in $FullExtras) {
        [void] $LogicalPackages.Add($name)
    }

    foreach ($name in $RepoPackages) {
        [void] $LogicalPackages.Add($name)
    }

    foreach ($name in $ConfigDirectoryNames) {
        [void] $LogicalPackages.Add($name)
    }
}

$LogicalPackages = @($LogicalPackages | Sort-Object -Unique)

Write-Section 'Resolving MSYS2 packages'

if ($DryRun -and -not (Test-Path -LiteralPath $Bash)) {
    $AvailablePackages = @{}
}
else {
    $AvailablePackages = @{}
    foreach ($packageName in (Invoke-Msys2 -Command 'pacman -Slq' -Capture)) {
        $trimmed = ([string] $packageName).Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            $AvailablePackages[$trimmed] = $true
        }
    }
}

function Test-MsysFallbackAllowed {
    param([Parameter(Mandatory)][string] $Name)

    return $MsysFallbackAllowlist -contains $Name
}

function Get-PackageCandidates {
    param(
        [Parameter(Mandatory)][string] $LogicalName,
        [Parameter(Mandatory)][bool] $AllowMsysFallback
    )

    $bases = New-Object System.Collections.Generic.List[string]

    if ($Aliases.ContainsKey($LogicalName)) {
        foreach ($alias in $Aliases[$LogicalName]) {
            [void] $bases.Add($alias)
        }
    }

    [void] $bases.Add($LogicalName)

    $candidates = New-Object System.Collections.Generic.List[string]

    foreach ($base in ($bases | Select-Object -Unique)) {
        if ($base -like 'mingw-w64-*') {
            [void] $candidates.Add($base)
            continue
        }

        [void] $candidates.Add("$PackagePrefix-$base")

        if ($AllowMsysFallback) {
            [void] $candidates.Add($base)
        }
    }

    return @($candidates | Select-Object -Unique)
}

$Resolved = New-Object System.Collections.Generic.List[object]
$Skipped = New-Object System.Collections.Generic.List[object]
$SelectedPackages = [ordered]@{}

foreach ($logicalName in $LogicalPackages) {
    if ($logicalName -notmatch '^[A-Za-z0-9][A-Za-z0-9+_.-]*$') {
        [void] $Skipped.Add([pscustomobject]@{
            Logical = $logicalName
            Reason = 'Invalid or unsafe package token'
        })
        continue
    }

    $allowMsys = Test-MsysFallbackAllowed -Name $logicalName

    # Curated package lists may intentionally use an alias whose fallback is
    # allowed even if the original logical name is not itself in the allowlist.
    $isCurated = ($CorePackages -contains $logicalName) -or
                 ($DevPackages -contains $logicalName) -or
                 ($FullExtras -contains $logicalName)

    if ($isCurated) {
        $allowMsys = $true
    }

    $candidates = Get-PackageCandidates -LogicalName $logicalName -AllowMsysFallback:$allowMsys
    $chosen = $null

    if ($DryRun -and $AvailablePackages.Count -eq 0) {
        # In an offline dry-run, show the preferred native package guess.
        $chosen = $candidates[0]
    }
    else {
        foreach ($candidate in $candidates) {
            if ($AvailablePackages.ContainsKey($candidate)) {
                $chosen = $candidate
                break
            }
        }
    }

    if ($null -eq $chosen) {
        [void] $Skipped.Add([pscustomobject]@{
            Logical = $logicalName
            Reason = 'No package in the active MSYS2 repositories'
        })
        continue
    }

    if (-not $SelectedPackages.Contains($chosen)) {
        $SelectedPackages[$chosen] = $true
    }

    [void] $Resolved.Add([pscustomobject]@{
        Logical = $logicalName
        Package = $chosen
    })
}

Write-Info ("flake.nix names discovered      : {0}" -f $RepoPackages.Count)
Write-Info (".config names discovered         : {0}" -f $ConfigDirectoryNames.Count)
Write-Info ("Logical package names considered : {0}" -f $LogicalPackages.Count)
Write-Info ("Resolved MSYS2 packages          : {0}" -f $SelectedPackages.Count)
Write-Info ("Unavailable / skipped            : {0}" -f $Skipped.Count)

if ($Profile -in @('Dev', 'Full')) {
    Write-Section 'Installing build groups'

    $groups = @(
        'base-devel',
        "$PackagePrefix-toolchain"
    )

    foreach ($group in $groups) {
        $quoted = ConvertTo-BashLiteral -Value $group

        if ($DryRun) {
            Write-Info "DRY RUN: pacman --needed --noconfirm -S $group"
            continue
        }

        Invoke-Msys2 -Command "pacman --needed --noconfirm -S $quoted" -AllowFailure
    }
}

function Split-Array {
    param(
        [Parameter(Mandatory)][object[]] $Items,
        [int] $Size = 24
    )

    for ($index = 0; $index -lt $Items.Count; $index += $Size) {
        $last = [Math]::Min($index + $Size - 1, $Items.Count - 1)
        , $Items[$index..$last]
    }
}

$FailedPackages = New-Object System.Collections.Generic.List[string]
$PackagesToInstall = @($SelectedPackages.Keys)

Write-Section 'Installing resolved packages'

if ($PackagesToInstall.Count -eq 0) {
    Write-Warn 'No packages were resolved for installation.'
}
else {
    $batchNumber = 0
    $batches = @(Split-Array -Items $PackagesToInstall -Size 24)

    foreach ($batch in $batches) {
        $batchNumber++
        $quotedPackages = @($batch | ForEach-Object { ConvertTo-BashLiteral -Value $_ })
        $command = 'pacman --needed --noconfirm -S ' + ($quotedPackages -join ' ')

        Write-Info "Installing batch $batchNumber of $($batches.Count) ($($batch.Count) packages)."

        if ($DryRun) {
            Write-Host $command
            continue
        }

        $batchFailed = $false

        try {
            Invoke-Msys2 -Command $command
        }
        catch {
            $batchFailed = $true
            Write-Warn "Batch install failed; retrying each package individually to maximize successful installs."
        }

        if ($batchFailed) {
            foreach ($package in $batch) {
                $quotedPackage = ConvertTo-BashLiteral -Value $package
                try {
                    Invoke-Msys2 -Command "pacman --needed --noconfirm -S $quotedPackage"
                }
                catch {
                    [void] $FailedPackages.Add($package)
                    Write-Warn "Could not install $package"
                }
            }
        }
    }
}

function Add-UserPathEntry {
    param([Parameter(Mandatory)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warn "PATH entry does not exist and will not be added: $Path"
        return
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($null -eq $userPath) {
        $userPath = ''
    }

    $entries = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $alreadyPresent = $false

    foreach ($entry in $entries) {
        if ($entry.TrimEnd('\') -ieq $Path.TrimEnd('\')) {
            $alreadyPresent = $true
            break
        }
    }

    if (-not $alreadyPresent) {
        $newPath = (($entries + $Path) | Select-Object -Unique) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Ok "Added to user PATH: $Path"
    }

    $processEntries = @($env:Path -split ';')
    if (-not ($processEntries | Where-Object { $_.TrimEnd('\') -ieq $Path.TrimEnd('\') })) {
        $env:Path = "$Path;$env:Path"
    }
}

if ($AddToUserPath -and -not $DryRun) {
    Write-Section 'PowerShell PATH integration'

    # Native MinGW/UCRT or Clang binaries are safe to expose directly.
    Add-UserPathEntry -Path $MingwBin

    # /usr/bin contains MSYS runtime tools and names that collide with Windows
    # utilities (find.exe, sort.exe, etc.), so this is opt-in.
    if ($AddMsysUsrBinToUserPath) {
        Add-UserPathEntry -Path $MsysUsrBin
        Write-Warn 'MSYS2 /usr/bin was added to PATH by request. Be aware of command-name collisions with Windows utilities.'
    }
    else {
        Write-Info 'MSYS2 /usr/bin was intentionally not added to the Windows PATH.'
    }
}

$InstalledPackages = @()
if (-not $DryRun -and (Test-Path -LiteralPath $Bash)) {
    $InstalledPackages = @(
        Invoke-Msys2 -Command 'pacman -Qq' -Capture |
            ForEach-Object { ([string] $_).Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
}

$Report = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('o')
    Profile = $Profile
    WindowsArchitecture = $WindowsArchitecture
    MsysEnvironment = $MsysEnvironment
    MsysRoot = $MsysRoot
    PackagePrefix = $PackagePrefix
    Repository = 'https://github.com/qompassai/dotfiles'
    RepoPackageDiscovery = (-not $SkipRepoPackageDiscovery)
    RepoFlakeDiscoveredCount = $RepoPackages.Count
    ConfigDirectoryDiscoveredCount = $ConfigDirectoryNames.Count
    LogicalPackageCount = $LogicalPackages.Count
    ResolvedPackageCount = $SelectedPackages.Count
    Resolved = @($Resolved)
    Skipped = @($Skipped)
    Failed = @($FailedPackages | Sort-Object -Unique)
    InstalledPackageCount = $InstalledPackages.Count
    Installed = $InstalledPackages
}

$ReportPath = Join-Path $HOME 'qompass-msys2-install-report.json'

if (-not $DryRun) {
    $Report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

Write-Section 'Summary'
Write-Ok "Profile complete: $Profile"
Write-Info "Resolved packages : $($SelectedPackages.Count)"
Write-Info "Skipped packages  : $($Skipped.Count)"
Write-Info "Failed packages   : $($FailedPackages.Count)"

if (-not $DryRun) {
    Write-Info "Install report    : $ReportPath"
}

if ($Skipped.Count -gt 0) {
    Write-Host ''
    Write-Host 'First unavailable/skipped package names:' -ForegroundColor Yellow

    $Skipped |
        Select-Object -First 40 |
        ForEach-Object {
            Write-Host ("  - {0}: {1}" -f $_.Logical, $_.Reason)
        }

    if ($Skipped.Count -gt 40) {
        Write-Host ("  ... plus {0} more; see the JSON report." -f ($Skipped.Count - 40))
    }
}

if ($FailedPackages.Count -gt 0) {
    Write-Host ''
    Write-Host 'Packages that resolved but failed to install:' -ForegroundColor Red
    $FailedPackages |
        Sort-Object -Unique |
        ForEach-Object { Write-Host "  - $_" }
}

Write-Host ''
Write-Ok "Open the configured environment with:"
Write-Host "  $MsysRoot\msys2_shell.cmd -defterm -here -no-start $($EnvironmentMetadata.ShellSwitch)"
Write-Host ''
Write-Info "The native environment bin directory is available to this PowerShell session at:"
Write-Host "  $MingwBin"
