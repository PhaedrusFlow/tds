@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "DURATION=30"
if not "%~1"=="" set "FIRST_ARG=%~1"
if defined DURATION if not "%DURATION%"=="" rem keep existing env override
if defined PARALLEL goto :after_parallel_default
set "PARALLEL=4"
:after_parallel_default
if defined REVERSE goto :after_reverse_default
set "REVERSE=0"
:after_reverse_default
if defined OUTDIR goto :after_outdir_default
set "OUTDIR=%CD%\iperf3-results"
:after_outdir_default

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%I"
set "LOGFILE=%OUTDIR%\iperf3-%STAMP%.log"
set "CSVFILE=%OUTDIR%\iperf3-%STAMP%.csv"

if not exist "%OUTDIR%" mkdir "%OUTDIR%"

where iperf3 >nul 2>&1
if errorlevel 1 (
  echo iperf3 is not installed.
  echo.
  echo Attempting install with WinGet...
  where winget >nul 2>&1
  if not errorlevel 1 (
    winget install -e --id iperf3.iperf3 --accept-package-agreements --accept-source-agreements
    where iperf3 >nul 2>&1
  )
)

where iperf3 >nul 2>&1
if errorlevel 1 (
  echo WinGet install did not succeed or WinGet is unavailable.
  echo Attempting install with Chocolatey...
  where choco >nul 2>&1
  if not errorlevel 1 (
    choco install iperf3 -y
    where iperf3 >nul 2>&1
  )
)

where iperf3 >nul 2>&1
if errorlevel 1 (
  echo.
  echo ERROR: iperf3 could not be installed automatically.
  echo Install one of these, then rerun:
  echo   winget install -e --id iperf3.iperf3
  echo   choco install iperf3 -y
  exit /b 1
)

> "%CSVFILE%" echo timestamp,server,mode,parallel,duration,summary

echo Writing logs to: %LOGFILE%
echo Writing csv to:  %CSVFILE%
echo.

if "%~1"=="" (
  call :run_test iperf.scottlinux.com
  timeout /t 2 /nobreak >nul
  call :run_test bouygues.testdebit.info
  timeout /t 2 /nobreak >nul
  call :run_test ping-90ms.online.net
) else (
  :server_loop
  if "%~1"=="" goto :done
  call :run_test %1
  shift
  if not "%~1"=="" timeout /t 2 /nobreak >nul
  goto :server_loop
)

goto :done

:run_test
set "SERVER=%~1"
set "MODE=upload"
set "EXTRA="
if "%REVERSE%"=="1" (
  set "MODE=download"
  set "EXTRA=-R"
)

echo ===== %SERVER% ^(%MODE%^) =====
>> "%LOGFILE%" echo ===== %SERVER% ^(%MODE%^) =====

set "TMPFILE=%TEMP%\iperf3-%RANDOM%%RANDOM%.tmp"
iperf3 -c "%SERVER%" -P %PARALLEL% -t %DURATION% %EXTRA% > "%TMPFILE%" 2>&1
set "RC=%ERRORLEVEL%"

type "%TMPFILE%"
>> "%LOGFILE%" type "%TMPFILE%"

if "%RC%"=="0" (
  set "SUMMARY="
  for /f "usebackq delims=" %%L in (`powershell -NoProfile -Command "$p='%TMPFILE%'; $m=Select-String -Path $p -Pattern '\[SUM\].*(sender|receiver)' | Select-Object -Last 1; if(-not $m){$m=Select-String -Path $p -Pattern '(sender|receiver)' | Select-Object -Last 1}; if($m){($m.Line -replace '^\s+','' -replace '\s+',' ')}"`) do set "SUMMARY=%%L"
  if not defined SUMMARY set "SUMMARY=NO SUMMARY FOUND"
  for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format s"') do set "NOW=%%I"
  >> "%CSVFILE%" echo !NOW!,%SERVER%,%MODE%,%PARALLEL%,%DURATION%,"!SUMMARY!"
) else (
  for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format s"') do set "NOW=%%I"
  >> "%CSVFILE%" echo !NOW!,%SERVER%,%MODE%,%PARALLEL%,%DURATION%,"FAILED"
  echo Test failed for %SERVER%
  >> "%LOGFILE%" echo Test failed for %SERVER%
)

del /q "%TMPFILE%" >nul 2>&1
>> "%LOGFILE%" echo.
echo.
exit /b 0

:done
echo Done. Review: %CSVFILE% and %LOGFILE%
echo Tip: run download tests with set REVERSE=1 ^&^& iperf3-multitest.cmd
echo Tip: override defaults with set DURATION=60 ^&^& set PARALLEL=8 ^&^& iperf3-multitest.cmd
endlocal
