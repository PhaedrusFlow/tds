@echo off
REM ============================================================================
REM jvm-optimize.cmd -- JVM optimization analysis for the Nokia 5520 AMS app
REM server (cmd.exe). Everything runs over ssh to amssys@%AMS_HOST%.
REM
REM Assumptions (from the guides; reported to the operator):
REM   A1. The AMS app server runs on a JVM (jstack/jmap via ams_support.sh,
REM       ams_check_ssl.sh JBoss/SSL check, JMS = Java Message Service).
REM   A2. The guides do NOT document the JDK version, current heap sizing,
REM       the GC in use, or how JVM flags are injected into AMS startup.
REM       Therefore this script NEVER edits AMS by default.
REM   A3. G1GC is recommended for a latency-sensitive management-plane
REM       workload (JDK 11+ default GC).
REM   A4. Heap ~= 50% of physical RAM, capped at 31 GB (compressed-oops
REM       ceiling), with -Xms == -Xmx to avoid heap-resize pauses.
REM
REM Default: probes the AMS host (read-only) and prints a recommended flag
REM block. Nothing is changed. Pass APPLYTO=<remote-file> to append the block
REM to a NEW file on the AMS host -- only after you type yes (timestamped
REM backup first if the file exists). It never touches AMS launch scripts
REM directly; you merge the file by hand using the documented mechanism.
REM
REM Usage: jvm-optimize.cmd [APPLYTO=<remote-file>] [YES=1]
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
echo JVM optimization analysis -- Nokia 5520 AMS app server
echo target: %TARGET%
echo ==============================================================
echo.
echo --- current JVM state (read-only probes) ---

set "JPID="
for /f %%p in ('ssh "%TARGET%" "pgrep -f 'java.*(ams|jboss|wildfly)' | head -1" 2^>nul') do set "JPID=%%p"
if not defined JPID (
    echo   WARNING: no obvious AMS java process found (looked for java with ams/jboss/wildfly in the cmdline^).
    echo   Identify the app-server PID and re-run, or run these checks by hand.
) else (
    echo   AMS java PID: !JPID!
    echo   $ ssh "%TARGET%" "jcmd !JPID! VM.version"
    ssh "%TARGET%" "jcmd !JPID! VM.version"
    echo   $ ssh "%TARGET%" "jcmd !JPID! VM.flags"
    ssh "%TARGET%" "jcmd !JPID! VM.flags"
    echo   $ ssh "%TARGET%" "jcmd !JPID! GC.heap_info"
    ssh "%TARGET%" "jcmd !JPID! GC.heap_info"
)

echo.
echo --- sizing recommendation ---
set "MEMKB="
for /f %%m in ('ssh "%TARGET%" "awk \"/^MemTotal:/ {print $2}\" /proc/meminfo"') do set "MEMKB=%%m"
set /a MEMGB=MEMKB/1024/1024
echo   physical RAM: !MEMGB! GB
set /a HEAPGB=MEMGB/2
if !HEAPGB! gtr 31 set "HEAPGB=31"
if !HEAPGB! lss 2 set "HEAPGB=2"
echo   recommended heap: !HEAPGB!g (50%% of RAM, capped at 31g for compressed oops)
echo   -Xms == -Xmx: avoids heap-resize pauses on a management-plane server

echo.
echo --- recommended flag block (REVIEW before applying) ---
echo.
echo   -Xms!HEAPGB!g
echo   -Xmx!HEAPGB!g
echo   -XX:+UseG1GC
echo   -XX:MaxGCPauseMillis=200
echo   -XX:+HeapDumpOnOutOfMemoryError
echo   -XX:HeapDumpPath=/var/log/ams/heapdump.hprof
echo   -Xlog:gc*:file=/var/log/ams/gc.log:time,uptime,level,tags:filecount=5,filesize=50M
echo.
echo   Notes:
echo   - G1GC: latency-sensitive default on JDK 11+; pause target 200 ms is a starting point, tune from gc.log.
echo   - GC logging (Xlog) and HeapDumpOnOutOfMemoryError: observability only, near-zero cost.
echo   - The guides do not document how AMS injects JVM flags (A2). Merge these into the AMS
echo     launch configuration by hand after checking the running VM.flags output above.
echo   - GC log / heap-dump paths assume /var/log/ams exists and is writable by the app server user.

if not defined APPLYTO (
    echo.
    echo No APPLYTO given: nothing was changed. Re-run with APPLYTO=^<remote-file^>
    echo to append the block above to a NEW file on the AMS host (with backup + typed yes^).
    exit /b 0
)

echo.
echo OPT-IN: append the flag block to '%APPLYTO%' on %TARGET%
if not defined YES (
    set /p "ANS=  This is a REAL change to the AMS host. Type "yes" to continue: "
    if /i not "!ANS!"=="yes" ( echo   aborted by operator. & exit /b 1 )
)

for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd-HHmmss'"') do set "STAMP=%%t"
echo   $ ssh "%TARGET%" "backup + append"
ssh "%TARGET%" "if [ -e '%APPLYTO%' ]; then cp -p '%APPLYTO%' '%APPLYTO%.bak-!STAMP!' && echo 'backup: %APPLYTO%.bak-!STAMP!'; fi"
if errorlevel 1 ( echo   FAILED: backup & exit /b 1 )
> "%TEMP%\jvmflags.txt" echo # JVM flags recommended by jvm-optimize.cmd (!STAMP!)
>>"%TEMP%\jvmflags.txt" echo -Xms!HEAPGB!g
>>"%TEMP%\jvmflags.txt" echo -Xmx!HEAPGB!g
>>"%TEMP%\jvmflags.txt" echo -XX:+UseG1GC
>>"%TEMP%\jvmflags.txt" echo -XX:MaxGCPauseMillis=200
>>"%TEMP%\jvmflags.txt" echo -XX:+HeapDumpOnOutOfMemoryError
>>"%TEMP%\jvmflags.txt" echo -XX:HeapDumpPath=/var/log/ams/heapdump.hprof
>>"%TEMP%\jvmflags.txt" echo -Xlog:gc*:file=/var/log/ams/gc.log:time,uptime,level,tags:filecount=5,filesize=50M
type "%TEMP%\jvmflags.txt" | ssh "%TARGET%" "cat >> '%APPLYTO%'"
if errorlevel 1 ( echo   FAILED: appending flags & del "%TEMP%\jvmflags.txt" & exit /b 1 )
del "%TEMP%\jvmflags.txt"
echo   appended to %APPLYTO% (merge into the AMS launch config by hand per A2).
exit /b 0
