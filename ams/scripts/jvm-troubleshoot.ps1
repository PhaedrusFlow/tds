<#
.SYNOPSIS
    JVM troubleshooting for the Nokia 5520 AMS app server (PowerShell).

.DESCRIPTION
    Everything runs over ssh to amssys@<AmsHost>. Two modes:

    READ-ONLY (default, no switches): gathers JVM state without touching
    anything -- jcmd VM.version / VM.flags / GC.heap_info, jstat -gcutil,
    jstack (thread dump to stdout only), and checks for existing GC logs and
    heap dumps on the AMS host.

    OPT-IN DUMPS: -ThreadDump writes a full jstack -l to a timestamped file on
    the AMS host; -HeapDump writes a live heap dump (jcmd GC.heap_dump) to a
    timestamped file on the AMS host. Each requires you to type "yes" first
    (skippable with -Yes -- the -ThreadDump/-HeapDump switch is still
    required, so a bare run can never dump by accident).

    GC logging and HeapDumpOnOutOfMemoryError are printed as recipes you can
    hand to jvm-optimize.ps1; they are never enabled by this script (they need
    a JVM restart, which this script will not trigger).

.PARAMETER AmsHost
    AMS server hostname/IP (ssh target as amssys@<AmsHost>).

.PARAMETER ThreadDump
    Opt in to writing a jstack -l thread dump file on the AMS host.

.PARAMETER HeapDump
    Opt in to writing a live heap dump file on the AMS host (pauses the JVM
    briefly while the heap is walked -- do this off-peak).

.PARAMETER Yes
    Skip the typed-yes confirmation (the dump switches are still required).
#>
[CmdletBinding()]
param(
    [string]$AmsHost = $env:AMS_HOST,
    [switch]$ThreadDump,
    [switch]$HeapDump,
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

Write-Host '=============================================================='
Write-Host 'JVM troubleshooting -- Nokia 5520 AMS app server'
Write-Host "target: $target"
Write-Host '=============================================================='
Write-Host ''

$jpid = ssh $target "pgrep -f 'java.*(ams|jboss|wildfly)' | head -1"
if ([string]::IsNullOrWhiteSpace($jpid)) {
    Write-Host '  ERROR: no AMS java process found. Identify the PID and check by hand.'
    exit 1
}
$jpid = $jpid.Trim()
Write-Host "  AMS java PID: $jpid"
Write-Host ''
Write-Host '--- read-only state (nothing is changed) ---'

foreach ($probe in @(
    "jcmd $jpid VM.version",
    "jcmd $jpid VM.flags | grep -E 'MaxHeapSize|InitialHeapSize|UseG1GC|G1HeapRegionSize|MaxGCPauseMillis|HeapDumpOnOutOfMemoryError|HeapDumpPath' || jcmd $jpid VM.flags",
    "jcmd $jpid GC.heap_info",
    "jstat -gcutil $jpid 1000 3"
)) {
    Write-Host ''
    Write-Host "  `$ ssh `"$target`" `"$probe`""
    ssh $target $probe
}

Write-Host ''
Write-Host '--- thread list (read-only, stdout only) ---'
ssh $target "jstack $jpid | head -60"
Write-Host '  (first 60 lines; full output stays on the AMS host unless -ThreadDump is used)'

Write-Host ''
Write-Host '--- existing diagnostics on the AMS host ---'
ssh $target "ls -lh /var/log/ams/gc*.log /var/log/ams/*.hprof 2>/dev/null || echo '  no GC logs or heap dumps found under /var/log/ams'"

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if ($ThreadDump) {
    Write-Host ''
    Write-Host 'OPT-IN: thread dump'
    if (-not $Yes) {
        $ans = Read-Host "  Writes jstack -l output to /var/log/ams/threaddump-$stamp.txt on $target. Type `"yes`" to continue"
        if ($ans -ne 'yes') { Write-Host '  thread dump skipped.' } else { $doTd = $true }
    } else { $doTd = $true }
    if ($doTd) {
        ssh $target "jstack -l $jpid > /var/log/ams/threaddump-$stamp.txt && ls -lh /var/log/ams/threaddump-$stamp.txt"
        if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: thread dump'; exit 1 }
        Write-Host "  thread dump saved: /var/log/ams/threaddump-$stamp.txt"
    }
}

if ($HeapDump) {
    Write-Host ''
    Write-Host 'OPT-IN: heap dump (pauses the JVM briefly -- prefer off-peak)'
    if (-not $Yes) {
        $ans = Read-Host "  Writes a live heap dump to /var/log/ams/heapdump-$stamp.hprof on $target. Type `"yes`" to continue"
        if ($ans -ne 'yes') { Write-Host '  heap dump skipped.' } else { $doHd = $true }
    } else { $doHd = $true }
    if ($doHd) {
        ssh $target "jcmd $jpid GC.heap_dump /var/log/ams/heapdump-$stamp.hprof && ls -lh /var/log/ams/heapdump-$stamp.hprof"
        if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: heap dump'; exit 1 }
        Write-Host "  heap dump saved: /var/log/ams/heapdump-$stamp.hprof"
    }
}

Write-Host ''
Write-Host '--- recipes (printed, never applied by this script) ---'
Write-Host '  GC logging for next restart (hand to jvm-optimize.ps1):'
Write-Host '    -Xlog:gc*:file=/var/log/ams/gc.log:time,uptime,level,tags:filecount=5,filesize=50M'
Write-Host '  Heap dump on OOM (hand to jvm-optimize.ps1):'
Write-Host '    -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/var/log/ams/heapdump.hprof'
Write-Host '  Both require a JVM restart, which this script will not trigger.'
Write-Host ''
Write-Host 'done.'
