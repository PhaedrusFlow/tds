<#
.SYNOPSIS
    JVM optimization analysis for the Nokia 5520 AMS app server (PowerShell).

.DESCRIPTION
    Assumptions (from the guides; reported to the operator):
      A1. The AMS app server runs on a JVM (evidence: jstack/jmap recipes via
          ams_support.sh, ams_check_ssl.sh JBoss/SSL checks, JMS is Java Message Service).
      A2. The guides do NOT document the JDK version, the current heap sizing,
          the GC in use, or how JVM flags are injected into AMS startup.
          Therefore this script NEVER edits AMS by default.
      A3. G1GC is recommended for a latency-sensitive management-plane
          workload (JDK 11+ default GC; low pause times at moderate heap sizes).
      A4. Heap ~= 50% of physical RAM, capped at 31 GB (compressed-oops
          ceiling), with -Xms == -Xmx to avoid heap resize pauses.

    Default behavior (no switches): probes the AMS host over ssh, reports the
    current JVM state (JDK version, flags, GC), and prints a recommended flag
    block. Nothing is changed.

    With -ApplyTo <remote-file>: appends the recommended flags to a NEW file
    at <remote-file> on the AMS host ONLY after you type "yes" (a timestamped
    backup is taken first if the file already exists). It never touches the
    AMS launch scripts directly -- the operator merges the file by hand using
    the documented AMS mechanism.

    Never bundle, download, or enable anything that phones home. GC logging and
    HeapDumpOnOOM are printed as recipes, never enabled without your consent.

.PARAMETER AmsHost
    AMS server hostname/IP (ssh target as amssys@<AmsHost>).

.PARAMETER ApplyTo
    Remote file path to append recommended flags to (opt-in only).

.PARAMETER Yes
    Skip the typed-yes confirmation (the -ApplyTo switch is still required).
#>
[CmdletBinding()]
param(
    [string]$AmsHost = $env:AMS_HOST,
    [string]$ApplyTo = '',
    [switch]$Yes
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

function Invoke-Remote {
    param([string]$Cmd)
    Write-Host "  `$ ssh `"$target`" `"$Cmd`""
    ssh $target $Cmd
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED (exit $LASTEXITCODE): $Cmd"
        exit 1
    }
}

Write-Host '=============================================================='
Write-Host 'JVM optimization analysis -- Nokia 5520 AMS app server'
Write-Host "target: $target"
Write-Host '=============================================================='
Write-Host ''
Write-Host '--- current JVM state (read-only probes) ---'

# Find the AMS java PID
$javaPid = ssh $target 'pgrep -f "java.*ams|jboss|wildfly" | head -1'
if ([string]::IsNullOrWhiteSpace($javaPid)) {
    Write-Host '  WARNING: no obvious AMS java process found (looked for java with ams/jboss/wildfly in the cmdline).'
    Write-Host '  Identify the app-server PID and re-run, or run these checks by hand.'
} else {
    $javaPid = $javaPid.Trim()
    Write-Host "  AMS java PID: $javaPid"
    Invoke-Remote "jcmd $javaPid VM.version 2>/dev/null || jcmd $javaPid VM.version"
    Invoke-Remote "jcmd $javaPid VM.flags"
    Invoke-Remote "jcmd $javaPid GC.heap_info"
}

Write-Host ''
Write-Host '--- sizing recommendation ---'
$memKb = ssh $target "awk '/^MemTotal:/ {print `$2}' /proc/meminfo"
$memGb = [math]::Floor([int]$memKb / 1024 / 1024)
Write-Host "  physical RAM: ${memGb} GB"
$heapGb = [math]::Min([math]::Floor($memGb / 2), 31)
if ($heapGb -lt 2) { $heapGb = 2 }
Write-Host "  recommended heap: ${heapGb}g (50% of RAM, capped at 31g for compressed oops)"
Write-Host '  -Xms == -Xmx: avoids heap-resize pauses on a management-plane server'

$flags = @(
    "-Xms${heapGb}g",
    "-Xmx${heapGb}g",
    '-XX:+UseG1GC',
    '-XX:MaxGCPauseMillis=200',
    '-XX:+HeapDumpOnOutOfMemoryError',
    '-XX:HeapDumpPath=/var/log/ams/heapdump.hprof',
    '-Xlog:gc*:file=/var/log/ams/gc.log:time,uptime,level,tags:filecount=5,filesize=50M'
)

Write-Host ''
Write-Host '--- recommended flag block (REVIEW before applying) ---'
Write-Host ''
$flags | ForEach-Object { Write-Host "  $_" }
Write-Host ''
Write-Host '  Notes:'
Write-Host '  - G1GC: latency-sensitive default on JDK 11+; pause target 200 ms is a starting point, tune from gc.log.'
Write-Host '  - GC logging (Xlog) and HeapDumpOnOutOfMemoryError: observability only, near-zero cost.'
Write-Host '  - The guides do not document how AMS injects JVM flags (A2). Merge these into the AMS'
Write-Host '    launch configuration by hand after checking the running VM.flags output above.'
Write-Host '  - GC log / heap-dump paths assume /var/log/ams exists and is writable by the app server user.'

if ([string]::IsNullOrEmpty($ApplyTo)) {
    Write-Host ''
    Write-Host 'No -ApplyTo given: nothing was changed. Re-run with -ApplyTo <remote-file>'
    Write-Host 'to append the block above to a NEW file on the AMS host (with backup + typed yes).'
    exit 0
}

Write-Host ''
Write-Host "OPT-IN: append the flag block to '$ApplyTo' on $target"
if (-not $Yes) {
    $ans = Read-Host '  This is a REAL change to the AMS host. Type "yes" to continue'
    if ($ans -ne 'yes') { Write-Host '  aborted by operator.'; exit 1 }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$block = ($flags -join "`n") -replace '"', '\"'
ssh $target "if [ -e '$ApplyTo' ]; then cp -p '$ApplyTo' '${ApplyTo}.bak-$stamp' && echo 'backup: ${ApplyTo}.bak-$stamp'; fi"
ssh $target "printf '%s\n' '# JVM flags recommended by jvm-optimize.ps1 ($stamp)' '$block' >> '$ApplyTo'"
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: appending flags'; exit 1 }
Write-Host "  appended to $ApplyTo (merge into the AMS launch config by hand per A2)."
