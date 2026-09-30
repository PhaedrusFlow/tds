@echo off
REM ============================================================================
REM jvm-troubleshoot.cmd -- JVM troubleshooting for the Nokia 5520 AMS app
REM server (cmd.exe). Everything runs over ssh to amssys@%AMS_HOST%.
REM
REM Default: READ-ONLY state gathering (jcmd VM.version / VM.flags /
REM GC.heap_info, jstat -gcutil, jstack to stdout, existing GC log/heap-dump
REM inventory). Nothing is changed.
REM
REM Opt-in dumps: THREADDUMP=1 writes jstack -l to a timestamped file on the
REM AMS host; HEAPDUMP=1 writes a live heap dump (brief JVM pause -- prefer
REM off-peak). Each requires you to type yes first (YES=1 skips the prompt,
REM but the THREADDUMP/HEAPDUMP switch is still required, so a bare run can
REM never dump by accident).
REM
REM GC logging and HeapDumpOnOutOfMemoryError are printed as recipes for
REM jvm-optimize.cmd -- never applied here (they need a JVM restart, which
REM this script will not trigger).
REM
REM Usage: jvm-troubleshoot.cmd [THREADDUMP=1] [HEAPDUMP=1] [YES=1]
REM ============================================================================
setlocal EnableDelayedExpansion

if not defined AMS_HOST (
    echo ERROR: AMS_HOST is not set. Run: set AMS_HOST=^<ams-host^>
    exit /b 1
)
where ssh >nul 2>&1
if errorlevel 1 (
    echo ERROR: ssh not found (install Win32 OpenSSH via Settings ^> Apps ^> Optional features^).
    exit /b 1
)
set "TARGET=amssys@%AMS_HOST%"

echo ==============================================================
echo JVM troubleshooting -- Nokia 5520 AMS app server
echo target: %TARGET%
echo ==============================================================
echo.

set "JPID="
for /f %%p in ('ssh "%TARGET%" "pgrep -f 'java.*(ams|jboss|wildfly)' | head -1" 2^>nul') do set "JPID=%%p"
if not defined JPID (
    echo   ERROR: no AMS java process found. Identify the PID and check by hand.
    exit /b 1
)
echo   AMS java PID: !JPID!
echo.
echo --- read-only state (nothing is changed) ---
echo.
echo   $ ssh "%TARGET%" "jcmd !JPID! VM.version"
ssh "%TARGET%" "jcmd !JPID! VM.version"
echo.
echo   $ ssh "%TARGET%" "jcmd !JPID! VM.flags"
ssh "%TARGET%" "jcmd !JPID! VM.flags | grep -E 'MaxHeapSize|InitialHeapSize|UseG1GC|MaxGCPauseMillis|HeapDumpOnOutOfMemoryError' || jcmd !JPID! VM.flags"
echo.
echo   $ ssh "%TARGET%" "jcmd !JPID! GC.heap_info"
ssh "%TARGET%" "jcmd !JPID! GC.heap_info"
echo.
echo   $ ssh "%TARGET%" "jstat -gcutil !JPID! 1000 3"
ssh "%TARGET%" "jstat -gcutil !JPID! 1000 3"

echo.
echo --- thread list (read-only, stdout only) ---
ssh "%TARGET%" "jstack !JPID! | head -60"
echo   (first 60 lines; full output stays on the AMS host unless THREADDUMP=1 is used)

echo.
echo --- existing diagnostics on the AMS host ---
ssh "%TARGET%" "ls -lh /var/log/ams/gc*.log /var/log/ams/*.hprof 2>/dev/null || echo '  no GC logs or heap dumps found under /var/log/ams'"

for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd-HHmmss'"') do set "STAMP=%%t"

if defined THREADDUMP (
    echo.
    echo OPT-IN: thread dump
    if not defined YES (
        set /p "ANS=  Writes jstack -l output to /var/log/ams/threaddump-!STAMP!.txt on %TARGET%. Type "yes" to continue: "
        if /i not "!ANS!"=="yes" ( echo   thread dump skipped. & goto :heap )
    )
    ssh "%TARGET%" "jstack -l !JPID! > /var/log/ams/threaddump-!STAMP!.txt && ls -lh /var/log/ams/threaddump-!STAMP!.txt"
    if errorlevel 1 ( echo   FAILED: thread dump & exit /b 1 )
    echo   thread dump saved: /var/log/ams/threaddump-!STAMP!.txt
)

:heap
if defined HEAPDUMP (
    echo.
    echo OPT-IN: heap dump (pauses the JVM briefly -- prefer off-peak)
    if not defined YES (
        set /p "ANS=  Writes a live heap dump to /var/log/ams/heapdump-!STAMP!.hprof on %TARGET%. Type "yes" to continue: "
        if /i not "!ANS!"=="yes" ( echo   heap dump skipped. & goto :recipes )
    )
    ssh "%TARGET%" "jcmd !JPID! GC.heap_dump /var/log/ams/heapdump-!STAMP!.hprof && ls -lh /var/log/ams/heapdump-!STAMP!.hprof"
    if errorlevel 1 ( echo   FAILED: heap dump & exit /b 1 )
    echo   heap dump saved: /var/log/ams/heapdump-!STAMP!.hprof
)

:recipes
echo.
echo --- recipes (printed, never applied by this script) ---
echo   GC logging for next restart (hand to jvm-optimize.cmd^):
echo     -Xlog:gc*:file=/var/log/ams/gc.log:time,uptime,level,tags:filecount=5,filesize=50M
echo   Heap dump on OOM (hand to jvm-optimize.cmd^):
echo     -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/var/log/ams/heapdump.hprof
echo   Both require a JVM restart, which this script will not trigger.
echo.
echo done.
exit /b 0
