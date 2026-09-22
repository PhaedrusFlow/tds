#Requires -Version 5.1
<#
.SYNOPSIS
    Dumps GlobalProtect VPN configuration (registry + files) so it can be
    replicated on a Linux client (openconnect --protocol=gp / globalprotect-openconnect).
.NOTES
    Run as a normal user. Some HKLM keys may require an elevated PowerShell
    session (Run as Administrator) to read if permissions are locked down.
#>

$ErrorActionPreference = 'SilentlyContinue'
$report = [System.Collections.Generic.List[string]]::new()

function Add-Section {
    param([string]$Title)
    $report.Add('')
    $report.Add("== $Title ==")
}

function Add-RegValues {
    param([string]$Path, [string]$Label)
    if (Test-Path $Path) {
        Add-Section $Label
        $item = Get-Item -Path $Path
        $props = $item.Property
        if (-not $props) {
            $report.Add("(key exists, no values)")
        }
        foreach ($p in $props) {
            $val = (Get-ItemProperty -Path $Path -Name $p).$p
            $report.Add("$p = $val")
        }
    }
    else {
        Add-Section $Label
        $report.Add("(not found: $Path)")
    }
}

# --- Machine-wide portal/setup info ---
Add-RegValues -Path 'HKLM:\SOFTWARE\Palo Alto Networks\GlobalProtect\PanSetup' -Label 'PanSetup (portal address, install info)'

# --- Machine-wide agent settings ---
Add-RegValues -Path 'HKLM:\SOFTWARE\Palo Alto Networks\GlobalProtect\Settings' -Label 'Machine Settings (HKLM)'

# --- Connect Before Logon ---
Add-RegValues -Path 'HKLM:\SOFTWARE\Palo Alto Networks\GlobalProtect\CBL' -Label 'Connect Before Logon (CBL)'

# --- Per-user settings (last used portal/gateway, SSO state) ---
Add-RegValues -Path 'HKCU:\SOFTWARE\Palo Alto Networks\GlobalProtect\Settings' -Label 'User Settings (HKCU, includes LastUrl)'

# --- WOW6432Node fallback (32-bit app on 64-bit OS) ---
Add-RegValues -Path 'HKLM:\SOFTWARE\WOW6432Node\Palo Alto Networks\GlobalProtect\PanSetup' -Label 'PanSetup (WOW6432Node fallback)'
Add-RegValues -Path 'HKLM:\SOFTWARE\WOW6432Node\Palo Alto Networks\GlobalProtect\Settings' -Label 'Machine Settings (WOW6432Node fallback)'

# --- Installed version / install path ---
Add-Section 'Install Info'
$installPath = 'C:\Program Files\Palo Alto Networks\GlobalProtect'
if (Test-Path $installPath) {
    $exe = Get-Item "$installPath\PanGPA.exe" -ErrorAction SilentlyContinue
    if ($exe) {
        $report.Add("Install path: $installPath")
        $report.Add("PanGPA.exe version: $($exe.VersionInfo.FileVersion)")
    }
}
else {
    $report.Add("(default install path not found: $installPath)")
}

# --- Per-user data directory (cached portal config, cookies, logs) ---
Add-Section 'Per-User Data Files'
$dataPath = "$env:LOCALAPPDATA\Palo Alto Networks\GlobalProtect"
if (Test-Path $dataPath) {
    $report.Add("Data path: $dataPath")
    Get-ChildItem $dataPath -File | ForEach-Object {
        $report.Add(" - $($_.Name)  ($([math]::Round($_.Length/1KB,1)) KB, modified $($_.LastWriteTime))")
    }
}
else {
    $report.Add("(not found: $dataPath)")
}

# --- Try to extract portal/gateway hostnames from the log, as a cross-check ---
Add-Section 'Portal/Gateway Strings Found in PanGPA.log'
$log = "$dataPath\PanGPA.log"
if (Test-Path $log) {
    $hits = Select-String -Path $log -Pattern 'portal|gateway' -SimpleMatch -CaseSensitive:$false |
        Select-Object -Last 20
    if ($hits) {
        foreach ($h in $hits) { $report.Add($h.Line.Trim()) }
    }
    else {
        $report.Add("(no portal/gateway lines found)")
    }
}
else {
    $report.Add("(log not found: $log)")
}

# --- Output ---
$outFile = "$env:USERPROFILE\Desktop\GlobalProtect-Config-Dump.txt"
$report | Out-File -FilePath $outFile -Encoding UTF8

Write-Host "`nGlobalProtect config dump written to: $outFile`n" -ForegroundColor Green
$report | ForEach-Object { Write-Host $_ }
