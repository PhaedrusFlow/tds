@echo off
setlocal

REM Salesforce CLI Setup
REM ----------------------------------------

set "INSTANCE_URL=https://tdstelecom.my.salesforce.com"
set "DEFAULT_ORG_ALIAS=tds"
sf config set disable-telemetry=true --global
if errorlevel 1 exit /b 1

sf config set org-api-version=67.0 --global
if errorlevel 1 exit /b 1

sf config set org-capitalize-record-types=false --global
if errorlevel 1 exit /b 1

sf config set org-max-query-limit=20000 --global
if errorlevel 1 exit /b 1

echo.
echo Current installed plugins:
sf plugins --core

call :install_plugin "@salesforce/sfdx-plugin-lwc-test@1.2.1"
call :install_plugin "@salesforce/plugin-devops-center@1.2.27"
call :install_plugin "@salesforce/plugin-marketplace@1.3.26"
call :install_plugin "@salesforce/plugin-code-analyzer@5.12.0"
call :install_plugin "@salesforce/plugin-agent@1.40.3"
call :install_plugin "@salesforce/plugin-flow@1.0.5"
call :install_plugin "@salesforce/plugin-lightning-dev@6.2.17"
call :install_plugin "@salesforce/plugin-ui-bundle-dev@1.2.2"

echo.
echo Installed plugins after updates:
sf plugins --core

echo.
set /p DEVHUB_ALIAS=Enter Dev Hub alias (example: map-dev): 

if "%DEVHUB_ALIAS%"=="" (
    echo Error: Dev Hub alias cannot be empty.
    exit /b 1
)

sf org login web ^
    --instance-url "%INSTANCE_URL%" ^
    --alias "%DEVHUB_ALIAS%" ^
    --set-default-dev-hub

if errorlevel 1 (
    echo Salesforce CLI login failed.
    exit /b 1
)

sf config set "target-dev-hub=%DEVHUB_ALIAS%" --global
if errorlevel 1 exit /b 1

sf config set "target-org=%DEVHUB_ALIAS%" --global
if errorlevel 1 exit /b 1

echo.
echo Verifying config:
sf config get target-org target-dev-hub --verbose

echo.
echo Dev Hub authorized and set.
echo Default Dev Hub alias: %DEVHUB_ALIAS%
echo Default org alias: %DEVHUB_ALIAS%
echo.
echo If you also want a general TDS alias, run:
echo sf alias set %DEFAULT_ORG_ALIAS%=YOUR_SALESFORCE_USERNAME

goto :eof

:install_plugin
echo.
echo Installing %~1
sf plugins install %~1
if errorlevel 1 (
    echo Warning: Failed to install %~1
)
goto :eof
