<#
.SYNOPSIS
    Verify (and optionally install) JVM diagnostic tooling for the AMS Java
    application server (PowerShell). Everything runs over ssh to amssys@<AmsHost>.

.DESCRIPTION
    Checks for the free, reputable tooling that makes JVM work sane, and tells
    you exactly how to get what's missing:
      JDK built-ins (free, ship with the JDK -- no download, no license):
        java, jstack, jmap, jcmd, jstat, jinfo, jconsole
      async-profiler (Apache 2.0): low-overhead CPU/alloc profiling; verified
        present or given the release URL + checksum steps. NEVER auto-downloaded.
      VisualVM (GPL-2.0): optional GUI profiler -- install hint only.

    Does not download anything without -AllowDownloads AND a typed "yes".
    Does not install anything without a typed "yes" (package manager only).
    Does not phone home: every check runs on the AMS host. No telemetry, no
    license servers, no accounts. If a tool ever needs a license, this script
    refuses to fetch it and says so loudly (none of the tools below do).

.PARAMETER AmsHost
    AMS server hostname/IP (ssh target as amssys@<AmsHost>).

.PARAMETER AllowDownloads
    Permit the script to walk you through fetching async-profiler (still asks
    first; automatic GitHub-release scraping is deliberately NOT implemented --
    picking the right build for your glibc/JDK is a human decision).

.PARAMETER Install
    Permit 'sudo dnf install' for missing JDK tooling (still asks first).
#>
[CmdletBinding()]
param(
    [string]$AmsHost = $env:AMS_HOST,
    [switch]$AllowDownloads,
    [switch]$Install
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($AmsHost)) {
    Write-Host 'ERROR: AMS_HOST is not set. Set $env:AMS_HOST or pass -AmsHost.'
    exit 1
}
$target = "amssys@$AmsHost"
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host 'ERROR: ssh not found (install Win32 OpenSSH via Settings > Apps > Optional features).'
    exit 1
}

$script:Missing = $false
function Write-Ok   { param([string]$t) Write-Host "  [ok] $t" }
function Write-Miss { param([string]$t) Write-Host "  [MISSING] $t"; $script:Missing = $true }

function Confirm-Yes {
    param([string]$Prompt)
    $ans = Read-Host "$Prompt Type `"yes`" to continue"
    return $ans -eq 'yes'
}

Write-Host "## JVM tooling check -- $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
Write-Host "## target: $target"
Write-Host ''

Write-Host '### 1. JDK built-ins (free, ship with the JDK)'
$java = ssh $target 'command -v java || true'
if ($java) {
    Write-Ok "java: $($java.Trim())"
    (ssh $target 'java -version 2>&1' | Select-Object -First 3) | ForEach-Object { Write-Host "         $_" }
} else {
    Write-Miss 'java not on PATH'
}
foreach ($t in @('jstack','jmap','jcmd','jstat','jinfo','jconsole')) {
    $p = ssh $target "command -v $t || true"
    if ($p) { Write-Ok "${t}: $($p.Trim())" }
    else    { Write-Miss "$t not found -- you have a JRE but not the JDK (devel package)" }
}
Write-Host ''
Write-Host '  fix (RHEL, match YOUR AMS release''s JDK first):'
Write-Host '    sudo dnf install java-17-openjdk-devel'
Write-Host ''

Write-Host '### 2. async-profiler (Apache 2.0 -- CPU/alloc profiling, ~no overhead)'
$apUrl = 'https://github.com/async-profiler/async-profiler/releases'
$ap = ssh $target 'command -v asprof || { [ -x /opt/async-profiler/bin/asprof ] && echo /opt/async-profiler/bin/asprof; } || true'
if ($ap) {
    Write-Ok "async-profiler present: $($ap.Trim())"
} else {
    Write-Miss 'async-profiler not found'
    Write-Host "  get it (manual, recommended): $apUrl"
    Write-Host '    1. download the linux-x64 tar.gz for your glibc'
    Write-Host '    2. verify the SHA256 checksum published on the release page:'
    Write-Host '         sha256sum async-profiler-*.tar.gz   # compare with the release page value'
    Write-Host '    3. extract to /opt/async-profiler (root) and use bin/asprof'
    if ($AllowDownloads) {
        Write-Host ''
        if (Confirm-Yes 'download the latest async-profiler release to /tmp and checksum-verify it?') {
            Write-Host '  NOTE: this step is intentionally manual -- download it yourself from:'
            Write-Host "  $apUrl"
            Write-Host '  Automatic GitHub-release scraping is deliberately NOT implemented here:'
            Write-Host '  picking the right build for your glibc/JDK is a human decision.'
        } else {
            Write-Host '  skipped by operator.'
        }
    } else {
        Write-Host '  (re-run with -AllowDownloads to be walked through the fetch)'
    }
}
Write-Host ''

Write-Host '### 3. VisualVM (optional GUI profiler, GPL-2.0)'
$vv = ssh $target 'command -v visualvm || true'
if ($vv) { Write-Ok "visualvm: $($vv.Trim())" }
else {
    Write-Miss 'visualvm not found (optional -- only useful with a display or remote JMX)'
    Write-Host '  get it: https://visualvm.github.io/  (or: sudo dnf install visualvm)'
}
Write-Host ''

Write-Host '### 4. package-manager install (only with -Install)'
if ($Install) {
    if (Confirm-Yes "run 'sudo dnf install java-17-openjdk-devel' on $target now?") {
        ssh -t $target 'sudo dnf install -y java-17-openjdk-devel'
        if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: dnf install'; exit 1 }
    } else {
        Write-Host '  skipped by operator.'
    }
} else {
    Write-Host '  skipped (re-run with -Install to permit dnf installs; still asks first)'
}
Write-Host ''

if ($script:Missing) {
    Write-Host 'result: some tooling is missing -- follow the fix hints above.'
    exit 1
}
Write-Host 'result: all checked tooling is present.'
