@echo off
REM ============================================================================
REM tooling-setup.cmd -- verify (and optionally install) JVM diagnostic
REM tooling for the AMS Java application server (cmd.exe). Everything runs
REM over ssh to amssys@%AMS_HOST%.
REM
REM Checks for the free, reputable tooling that makes JVM work sane, and tells
REM you exactly how to get what's missing:
REM   JDK built-ins (free, ship with the JDK -- no download, no license):
REM     java, jstack, jmap, jcmd, jstat, jinfo, jconsole
REM   async-profiler (Apache 2.0): low-overhead CPU/alloc profiling; verified
REM     present or given the release URL + checksum steps. NEVER auto-downloaded.
REM   VisualVM (GPL-2.0): optional GUI profiler -- install hint only.
REM
REM Does not download anything without ALLOWDL=1 AND a typed "yes".
REM Does not install anything without a typed "yes" (package manager only).
REM Does not phone home: every check runs on the AMS host. No telemetry, no
REM license servers, no accounts. If a tool ever needs a license, this script
REM refuses to fetch it and says so loudly (none of the tools below do).
REM
REM Usage: tooling-setup.cmd [ALLOWDL=1] [INSTALL=1]
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
set "MISSING=0"
set "AP_URL=https://github.com/async-profiler/async-profiler/releases"

for /f %%t in ('powershell -NoProfile -Command "(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')"') do set "NOWUTC=%%t"
echo ## JVM tooling check -- !NOWUTC!
echo ## target: %TARGET%
echo.

echo ### 1. JDK built-ins (free, ship with the JDK^)
set "P="
for /f "delims=" %%p in ('ssh "%TARGET%" "command -v java || true" 2^>nul') do set "P=%%p"
if defined P (
    echo   [ok] java: !P!
    set /a N=0
    for /f "delims=" %%v in ('ssh "%TARGET%" "java -version 2^>^&1" 2^>nul') do (
        if !N! lss 3 echo          %%v
        set /a N+=1
    )
) else (
    echo   [MISSING] java not on PATH
    set "MISSING=1"
)
for %%t in (jstack jmap jcmd jstat jinfo jconsole) do (
    set "P="
    for /f "delims=" %%p in ('ssh "%TARGET%" "command -v %%t || true" 2^>nul') do set "P=%%p"
    if defined P ( echo   [ok] %%t: !P! ) else (
        echo   [MISSING] %%t not found -- you have a JRE but not the JDK (devel package^)
        set "MISSING=1"
    )
)
echo.
echo   fix (RHEL, match YOUR AMS release's JDK first^):
echo     sudo dnf install java-17-openjdk-devel
echo.

echo ### 2. async-profiler (Apache 2.0 -- CPU/alloc profiling, ~no overhead^)
set "P="
for /f "delims=" %%p in ('ssh "%TARGET%" "command -v asprof || { [ -x /opt/async-profiler/bin/asprof ] ^&^& echo /opt/async-profiler/bin/asprof; } || true" 2^>nul') do set "P=%%p"
if defined P (
    echo   [ok] async-profiler present: !P!
) else (
    echo   [MISSING] async-profiler not found
    set "MISSING=1"
    echo   get it (manual, recommended^): !AP_URL!
    echo     1. download the linux-x64 tar.gz for your glibc
    echo     2. verify the SHA256 checksum published on the release page:
    echo          sha256sum async-profiler-*.tar.gz   # compare with the release page value
    echo     3. extract to /opt/async-profiler (root^) and use bin/asprof
    if defined ALLOWDL (
        echo.
        set /p "ANS=  download the latest async-profiler release to /tmp and checksum-verify it? Type "yes" to continue: "
        if /i "!ANS!"=="yes" (
            echo   NOTE: this step is intentionally manual -- download it yourself from:
            echo   !AP_URL!
            echo   Automatic GitHub-release scraping is deliberately NOT implemented here:
            echo   picking the right build for your glibc/JDK is a human decision.
        ) else (
            echo   skipped by operator.
        )
    ) else (
        echo   (re-run with ALLOWDL=1 to be walked through the fetch^)
    )
)
echo.

echo ### 3. VisualVM (optional GUI profiler, GPL-2.0^)
set "P="
for /f "delims=" %%p in ('ssh "%TARGET%" "command -v visualvm || true" 2^>nul') do set "P=%%p"
if defined P (
    echo   [ok] visualvm: !P!
) else (
    echo   [MISSING] visualvm not found (optional -- only useful with a display or remote JMX^)
    set "MISSING=1"
    echo   get it: https://visualvm.github.io/  (or: sudo dnf install visualvm^)
)
echo.

echo ### 4. package-manager install (only with INSTALL=1^)
if defined INSTALL (
    set /p "ANS=  run 'sudo dnf install java-17-openjdk-devel' on %TARGET% now? Type "yes" to continue: "
    if /i "!ANS!"=="yes" (
        ssh -t "%TARGET%" "sudo dnf install -y java-17-openjdk-devel"
        if errorlevel 1 ( echo   FAILED: dnf install & exit /b 1 )
    ) else (
        echo   skipped by operator.
    )
) else (
    echo   skipped (re-run with INSTALL=1 to permit dnf installs; still asks first^)
)
echo.

if "%MISSING%"=="1" (
    echo result: some tooling is missing -- follow the fix hints above.
    exit /b 1
)
echo result: all checked tooling is present.
exit /b 0
