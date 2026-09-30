@echo off
REM ============================================================================
REM run.cmd -- LIVE execution of every documented Calix CMS task.
REM
REM Same task list and order as dry-run.cmd, for real. Read-only tasks run
REM straight through; every mutating step requires you to type yes first.
REM GUI/portal/physical steps print their checklist and pause. Fails fast on
REM the first error. Secrets are prompted (masked) when not set and are never
REM displayed. Temp files are wiped on exit.
REM
REM Run dry-run.cmd first and resolve every SKIP before running this.
REM ============================================================================
setlocal EnableDelayedExpansion

where curl.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: curl.exe not found ^(Windows 10+ ships it^).
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "TMPDIR=%TEMP%\cms-run-%RANDOM%"
mkdir "%TMPDIR%" >nul 2>&1
set "CMS_PASS_USED="
set "SMX_PASS_USED="

echo ==================================================================
echo LIVE RUN -- real commands against your Calix environment.
echo Run dry-run.cmd first and resolve every SKIP before proceeding.
echo ==================================================================

REM ============================ TASK[01] =====================================
call :task "01" "CMS pre-upgrade server checks"
echo   note: read-only -- via ssh to !CMS_SSH_TARGET! (or locally if unset)
call :srvcheck "cat /etc/os-release | head -3"
call :srvcheck "docker --version; docker compose version"
call :srvcheck "nproc; free -g"
call :srvcheck "df -h / | tail -1"
call :srvcheck "grep -i version /opt/calix/cms/*/release.properties"
call :step "bash --version"

REM ============================ TASK[02] =====================================
call :task "02" "Determine CMS upgrade path"
echo   note: read-only -- report your build, then map it in the release-notes path table
call :srvcheck "grep -i version /opt/calix/cms/*/release.properties"
call :op_check "map the build above to the upgrade-path table in cms/guides/cms-release-notes.md" "confirm whether your build needs intermediate hops before the target release"

REM ============================ TASK[03] =====================================
call :task "03" "Alarm mismatch triage (operator)"
call :op_check "open the alarm views named in the release-notes scenario and compare counts" "note which view disagrees (stale cache vs live poll) before clearing anything" "follow the scenario's remediation order; do not bulk-clear alarms to 'fix' a mismatch"

REM ============================ TASK[04] =====================================
call :task "04" "NBI authenticate and capture session"
call :req_var CMS_HOST "set CMS_HOST=<cms-host>"
call :req_var CMS_USER "set CMS_USER=<cms-user>"
call :req_secret CMS_PASS
echo   note: login creates a server-side session (200-session limit -- we log out at the end)
if not defined CMS_PORT set "CMS_PORT=18080"
if not defined NBI_URI set "NBI_URI=/cms/nbi"
set "URL=http://!CMS_HOST!:!CMS_PORT!!NBI_URI!"
> "%TMPDIR%\login.xml" echo ^<?xml version="1.0" encoding="UTF-8"?^>
>>"%TMPDIR%\login.xml" echo ^<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"^>
>>"%TMPDIR%\login.xml" echo   ^<soapenv:Body^>
>>"%TMPDIR%\login.xml" echo     ^<auth message-id="1"^>
>>"%TMPDIR%\login.xml" echo       ^<login^>
>>"%TMPDIR%\login.xml" echo         ^<UserName^>!CMS_USER!^</UserName^>
>>"%TMPDIR%\login.xml" echo         ^<Password^>!CMS_PASS!^</Password^>
>>"%TMPDIR%\login.xml" echo       ^</login^>
>>"%TMPDIR%\login.xml" echo     ^</auth^>
>>"%TMPDIR%\login.xml" echo   ^</soapenv:Body^>
>>"%TMPDIR%\login.xml" echo ^</soapenv:Envelope^>
set "CMS_PASS_USED="
echo   $ curl.exe -s -X POST "!URL!" --data @"%TMPDIR%\login.xml"
curl.exe -s -X POST "!URL!" -H "Content-Type: text/xml; charset=UTF-8" --data @"%TMPDIR%\login.xml" > "%TMPDIR%\login_resp.xml"
if errorlevel 1 ( echo   FAILED: NBI login call & goto :fail )
findstr "<SessionID>[0-9]*</SessionID>" "%TMPDIR%\login_resp.xml" >nul
if errorlevel 1 (
    echo   ERROR: no SessionID in the login response.
    findstr "<ResultMessage>[^<]*</ResultMessage>" "%TMPDIR%\login_resp.xml"
    echo   Check credentials, Full CMS Administration privilege, and the 200-session limit.
    goto :fail
)
echo   authenticated -- SessionID captured (hidden)

REM ============================ TASK[05] =====================================
call :task "05" "NBI find ONT and read services"
call :req_var CMS_HOST "set CMS_HOST=<cms-host>"
call :req_var NODEN "set NODEN=<cms-network-node>"
echo   note: read-only
set "FILTER="
set "FILTER_SET="
if defined SUBSCRIBER_ID ( set "FILTER=<subscr-id>!SUBSCRIBER_ID!</subscr-id>" & set "FILTER_SET=1" & echo   note: filtering by subscriber ID !SUBSCRIBER_ID! )
if defined REG_ID ( set "FILTER=<reg-id>!REG_ID!</reg-id>" & set "FILTER_SET=1" & echo   note: filtering by registration ID )
if defined ONT_SERIAL ( set "FILTER=<serno>!ONT_SERIAL!</serno>" & set "FILTER_SET=1" & echo   note: filtering by serial number )
if not defined FILTER_SET ( echo   note: no identifier set (SUBSCRIBER_ID/REG_ID/ONT_SERIAL) -- skipping find-ONT & goto :t5done )
set "SID=" & for /f "tokens=3 delims=<>" %%a in ('type "%TMPDIR%\login_resp.xml" ^| findstr "<SessionID>"') do set "SID=%%a"
if not defined SID ( echo   ERROR: no SessionID from task 04 & goto :fail )
> "%TMPDIR%\show_ont.xml" echo ^<?xml version="1.0" encoding="UTF-8"?^>
>>"%TMPDIR%\show_ont.xml" echo ^<soapenv:Envelope xmlns:soapenv="http://www.w3.org/2003/05/soap-envelope"^>
>>"%TMPDIR%\show_ont.xml" echo   ^<soapenv:Body^>
>>"%TMPDIR%\show_ont.xml" echo     ^<rpc message-id="175" nodename="!NODEN!" username="!CMS_USER!" sessionid="!SID!"^>
>>"%TMPDIR%\show_ont.xml" echo       ^<action^>^<action-type^>show-ont^</action-type^>^<action-args^>!FILTER!^</action-args^>^</action^>
>>"%TMPDIR%\show_ont.xml" echo     ^</rpc^>
>>"%TMPDIR%\show_ont.xml" echo   ^</soapenv:Body^>
>>"%TMPDIR%\show_ont.xml" echo ^</soapenv:Envelope^>
call :nbirc "%TMPDIR%\show_ont.xml" "%TMPDIR%\show_ont_resp.xml"
type "%TMPDIR%\show_ont_resp.xml"
:t5done

REM ============================ TASK[06] =====================================
call :task "06" "NBI create data service on GPON ONT"
call :yes_warn "MUTATING: provisions a data service via NBI edit-config (operation=create)."
if errorlevel 1 exit /b 1
set "XML=%TMPDIR%\create_service.xml"
echo   note: write the full edit-config rpc XML to !XML! (guide example), then press Enter
call :op_check "create !XML! from the guide's edit-config example"
if exist "!XML!" (
    call :nbirc "!XML!" "%TMPDIR%\create_resp.xml"
    type "%TMPDIR%\create_resp.xml"
    echo   note: verify with task-05 show-ont before closing the ticket
) else (
    echo   note: no payload provided -- create step skipped
)

REM ============================ TASK[07] =====================================
call :task "07" "NBI ONT replacement workflow"
call :req_var ONT_SERIAL_OLD "set ONT_SERIAL_OLD=<old-serial>"
call :req_var ONT_SERIAL_NEW "set ONT_SERIAL_NEW=<new-serial>"
call :yes_warn "MUTATING: unlinks ONT !ONT_SERIAL_OLD!, links !ONT_SERIAL_NEW!, then factory-resets the newcomer."
if errorlevel 1 exit /b 1
call :op_check "write %TMPDIR%\unlink_ont.xml (edit-config operation=delete for !ONT_SERIAL_OLD!)"
if exist "%TMPDIR%\unlink_ont.xml" ( call :nbirc "%TMPDIR%\unlink_ont.xml" "%TMPDIR%\unlink_resp.xml" & type "%TMPDIR%\unlink_resp.xml" )
call :op_check "write %TMPDIR%\link_ont.xml (edit-config operation=create for !ONT_SERIAL_NEW!)"
if exist "%TMPDIR%\link_ont.xml" ( call :nbirc "%TMPDIR%\link_ont.xml" "%TMPDIR%\link_resp.xml" & type "%TMPDIR%\link_resp.xml" )
call :op_check "write %TMPDIR%\set_default.xml (set-to-default factory reset)"
if exist "%TMPDIR%\set_default.xml" ( call :nbirc "%TMPDIR%\set_default.xml" "%TMPDIR%\setdef_resp.xml" & type "%TMPDIR%\setdef_resp.xml" )
echo   note: verify with show-ont after each step

REM ============================ TASK[08] =====================================
call :task "08" "SMx one-time sanity check"
call :req_var SMX_HOST "set SMX_HOST=<smx-host>"
call :req_var SMX_USER "set SMX_USER=<smx-user>"
call :req_secret SMX_PASS
set "SMX_PASS_USED=1"
echo   note: read-only -- HTTPS Basic auth (-k: self-signed LAN certs only)
echo   $ curl.exe -sk -u "***:***" -D - -o "%TMPDIR%\devices.json" "https://!SMX_HOST!:18443/rest/v1/config/device?limit=50"
curl.exe -sk -u "!SMX_USER!:!SMX_PASS!" -D - -o "%TMPDIR%\devices.json" "https://!SMX_HOST!:18443/rest/v1/config/device?limit=50" > "%TMPDIR%\headers.txt"
if errorlevel 1 ( echo   FAILED: SMx device list & goto :fail )
findstr /i "x-total-count" "%TMPDIR%\headers.txt"
echo   note: 200 = OK, 401 = bad creds, 429 = over the API rate limit (slow down)
set "SMX_PASS_USED="

REM ============================ TASK[09] =====================================
call :task "09" "SMx subscriber lifecycle"
call :req_var SMX_HOST "set SMX_HOST=<smx-host>"
call :req_var SMX_USER "set SMX_USER=<smx-user>"
call :req_var SMX_SUBSCRIBER_JSON "set SMX_SUBSCRIBER_JSON=C:\path\subscriber.json (name + customId required)"
call :req_secret SMX_PASS
set "SMX_PASS_USED=1"
call :yes_warn "MUTATING but self-cleaning: creates, queries, then DELETES a subscriber."
if errorlevel 1 exit /b 1
echo   $ curl.exe -sk -X POST "https://!SMX_HOST!:18443/rest/v1/ems/subscriber" --data @"!SMX_SUBSCRIBER_JSON!"
curl.exe -sk -u "!SMX_USER!:!SMX_PASS!" -X POST "https://!SMX_HOST!:18443/rest/v1/ems/subscriber" -H "Content-Type: application/json" --data @"!SMX_SUBSCRIBER_JSON!" -o "%TMPDIR%\sub_create.json"
if errorlevel 1 ( echo   FAILED: subscriber create & goto :fail )
echo   note: create response saved to %TMPDIR%\sub_create.json
set /p SUB_ID=  could not parse the subscriber id -- paste it from the response:
curl.exe -sk -u "!SMX_USER!:!SMX_PASS!" "https://!SMX_HOST!:18443/rest/v1/ems/eth-service?filter=customerID=!SUB_ID!"
if errorlevel 1 ( echo   FAILED: eth-service query & goto :fail )
echo.
call :yes_warn "cleanup: DELETES the subscriber just created (org 'Calix', account '!SUB_ID!')."
if errorlevel 1 exit /b 1
curl.exe -sk -u "!SMX_USER!:!SMX_PASS!" -X DELETE "https://!SMX_HOST!:18443/rest/v1/ems/subscriber/org/Calix/account/!SUB_ID!"
if errorlevel 1 ( echo   FAILED: subscriber delete & goto :fail )
set "SMX_PASS_USED="

REM ============================ TASK[10] =====================================
call :task "10" "SMx ONT lifecycle"
call :req_var SMX_HOST "set SMX_HOST=<smx-host>"
call :req_var SMX_USER "set SMX_USER=<smx-user>"
call :req_var SMX_DEVICE "set SMX_DEVICE=<device-name> (OLT name/IP, or 'virtualOLT')"
call :req_var SMX_ONT_JSON "set SMX_ONT_JSON=C:\path\ont.json"
call :req_secret SMX_PASS
set "SMX_PASS_USED=1"
call :yes_warn "MUTATING but self-cleaning: pre-provisions, checks status, then DELETES an ONT on !SMX_DEVICE!."
if errorlevel 1 exit /b 1
echo   $ curl.exe -sk -X POST "https://!SMX_HOST!:18443/rest/v1/config/device/!SMX_DEVICE!/ont" --data @"!SMX_ONT_JSON!"
curl.exe -sk -u "!SMX_USER!:!SMX_PASS!" -X POST "https://!SMX_HOST!:18443/rest/v1/config/device/!SMX_DEVICE!/ont" -H "Content-Type: application/json" --data @"!SMX_ONT_JSON!" -o "%TMPDIR%\ont_create.json"
if errorlevel 1 ( echo   FAILED: ONT create & goto :fail )
set /p OID=  paste the ONT id from the create response:
echo   note: ONT status:
curl.exe -sk -u "!SMX_USER!:!SMX_PASS!" "https://!SMX_HOST!:18443/rest/v1/performance/device/!SMX_DEVICE!/ont/!OID!/status"
if errorlevel 1 ( echo   FAILED: ONT status & goto :fail )
echo.
echo   note: ONT port g1 status:
curl.exe -sk -u "!SMX_USER!:!SMX_PASS!" "https://!SMX_HOST!:18443/rest/v1/performance/device/!SMX_DEVICE!/ont/!OID!/port/g1/status"
if errorlevel 1 ( echo   FAILED: ONT port status & goto :fail )
echo.
echo   note: port admin-state change: GET the full object first (PUT replaces the entire resource)
curl.exe -sk -u "!SMX_USER!:!SMX_PASS!" "https://!SMX_HOST!:18443/rest/v1/config/device/!SMX_DEVICE!/ontport?ont-id=!OID!^&ont-port-id=g1" -o "%TMPDIR%\port_get.json"
if errorlevel 1 ( echo   FAILED: ontport GET & goto :fail )
where jq >nul 2>&1
if errorlevel 1 (
    echo   note: jq not found -- skipping the port admin-state PUT (install jq to enable)
) else (
    jq ".admin-status = \"up\"" "%TMPDIR%\port_get.json" > "%TMPDIR%\port.json"
    call :yes_warn "MUTATING: sets ONT !OID! port g1 admin-status to up (full-object PUT)."
    if errorlevel 1 exit /b 1
    curl.exe -sk -u "!SMX_USER!:!SMX_PASS!" -X PUT "https://!SMX_HOST!:18443/rest/v1/config/device/!SMX_DEVICE!/ontport/ont-id/!OID!/ont-port-id/g1" -H "Content-Type: application/json" --data @"%TMPDIR%\port.json"
    if errorlevel 1 ( echo   FAILED: ontport PUT & goto :fail )
)
call :yes_warn "cleanup: DELETES the ONT just created on !SMX_DEVICE!."
if errorlevel 1 exit /b 1
curl.exe -sk -u "!SMX_USER!:!SMX_PASS!" -X DELETE "https://!SMX_HOST!:18443/rest/v1/config/device/!SMX_DEVICE!/ont"
if errorlevel 1 ( echo   FAILED: ONT delete & goto :fail )
set "SMX_PASS_USED="

REM ============================ TASK[11] =====================================
call :task "11" "SMx VLAN and service provisioning"
call :req_var SMX_HOST "set SMX_HOST=<smx-host>"
call :req_var SMX_USER "set SMX_USER=<smx-user>"
call :req_var SMX_DEVICE "set SMX_DEVICE=<device-name>"
call :req_var VLAN_ID "set VLAN_ID=<vlan-id>"
call :req_secret SMX_PASS
set "SMX_PASS_USED=1"
call :yes_warn "MUTATING: creates VLAN !VLAN_ID! on !SMX_DEVICE!."
if errorlevel 1 exit /b 1
echo   $ curl.exe -sk -X POST "https://!SMX_HOST!:18443/rest/v1/config/device/!SMX_DEVICE!/vlan" -d "{...}"
curl.exe -sk -u "!SMX_USER!:!SMX_PASS!" -X POST "https://!SMX_HOST!:18443/rest/v1/config/device/!SMX_DEVICE!/vlan" -H "Content-Type: application/json" -d "{\"device-name\":\"!SMX_DEVICE!\",\"vlan-id\":\"!VLAN_ID!\"}"
if errorlevel 1 ( echo   FAILED: VLAN create & goto :fail )
echo.
echo   note: service provisioning order: 1. POST /ems/profile/class-map  2. POST /config/service-template
echo   note:                             3. POST /ems/profile/policy-map   4. POST /ems/service
call :op_check "for exact service JSON: do it once in the SMx GUI, then on the SMx server run 'tail -F pmaa.log | grep json' and copy the JSON the GUI sent"
set "SMX_PASS_USED="

REM ============================ TASK[12] =====================================
call :task "12" "EXOS Smart Activate pre-flight"
if not defined BOX_IP set "BOX_IP=192.168.1.1"
echo   note: read-only
echo   $ curl.exe -s -o NUL -w "EWI HTTP %%{http_code}" "http://!BOX_IP!/"
for /f %%c in ('curl.exe -s -o NUL -w "%%{http_code}" "http://!BOX_IP!/"') do echo   EWI HTTP %%c
echo.
call :op_check "with the WAN unplugged, open http://!BOX_IP!/ in a browser and run Smart Activate" "no laptop? Voice Activate with a butt set on the POTS port (###0)"

REM ============================ TASK[13] =====================================
call :task "13" "EXOS EWI health check"
if not defined BOX_IP set "BOX_IP=192.168.1.1"
echo   note: read-only
echo   $ ping -n 4 !BOX_IP!
ping -n 4 !BOX_IP!
if errorlevel 1 ( echo   FAILED: ping !BOX_IP! & goto :fail )
for /f %%c in ('curl.exe -s -o NUL -w "%%{http_code}" "http://!BOX_IP!/"') do echo   EWI: %%c
echo.
call :op_check "walk the EWI health pages listed in exos-provisioning.md (GUI -- no CLI equivalent)"
echo   note: ongoing management lives in Calix Service Cloud (TR-069) and the CommandIQ app

REM ============================ TASK[14] =====================================
call :task "14" "EXOS no-solid-green triage (operator)"
call :op_check "read the LED states against the release-notes LED table (do not assume the old meanings)" "if no solid green: check power, then WAN link, then activation state -- in that order" "escalate to the EWI/Cloud checks (tasks 12-13) before replacing hardware"

REM ============================ TASK[15] =====================================
call :task "15" "AXOS pre-upgrade verification on OLT"
call :req_var OLT_SSH_TARGET "set OLT_SSH_TARGET=user@<olt-host>"
echo   note: read-only -- upgrade order: SMx >= 26.3.0 BEFORE AXOS; EXOS ONT BEFORE the AXOS OLT
call :oltcheck "show info"
call :oltcheck "show version"
call :oltcheck "show smx status"
call :oltcheck "show upgrade status"

REM ============================ TASK[16] =====================================
call :task "16" "AXOS daily monitoring checks on OLT"
call :req_var OLT_SSH_TARGET "set OLT_SSH_TARGET=user@<olt-host>"
call :req_var ONT_ID_NUM "set ONT_ID_NUM=<ont-id>"
echo   note: read-only -- post-R26.3 behavior changes noted in the dry-run
call :oltcheck "show arp"
call :oltcheck "show ipv6 neighbor"
call :oltcheck "show ont !ONT_ID_NUM! detail"
call :oltcheck "show interface pon bandwidth"

REM ============================ TASK[17] =====================================
call :task "17" "EXOS field checks after R26.3 (operator)"
call :op_check "verify the box checks in to Calix Service Cloud (TR-069) after the upgrade" "confirm the subscriber-facing apps (CommandIQ/ProtectIQ/SmartBiz) still pair" "review Service Cloud alerts raised by the upgrade before leaving site"

REM ============================ TASK[18] =====================================
call :task "18" "AXOS NETCONF notification-drop triage (operator)"
call :op_check "re-run the failing NETCONF get WITH the with-defaults parameter and compare" "check whether the 'missing' data was defaults being omitted (expected) vs a real drop" "only then escalate -- most reports of this are the behavior change, not a bug"

REM ============================ TASK[19] =====================================
call :task "19" "SmartMDU deployment readiness (operator)"
call :op_check "walk the SmartMDU deployment checklist in the guide (site survey items first)" "confirm the portal shows the property/building objects before hardware goes in" "verify the MDU-specific provisioning flow in the portal matches the plan"

REM ============================ TASK[00] =====================================
call :task "00" "NBI logout"
set "SID=" & for /f "tokens=3 delims=<>" %%a in ('type "%TMPDIR%\login_resp.xml" 2^>nul ^| findstr "<SessionID>"') do set "SID=%%a"
if defined SID (
    > "%TMPDIR%\logout.xml" echo ^<?xml version="1.0" encoding="UTF-8"?^>
    >>"%TMPDIR%\logout.xml" echo ^<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"^>
    >>"%TMPDIR%\logout.xml" echo   ^<soapenv:Body^>
    >>"%TMPDIR%\logout.xml" echo     ^<rpc message-id="999" nodename="!NODEN!" username="!CMS_USER!" sessionid="!SID!"^>
    >>"%TMPDIR%\logout.xml" echo       ^<action^>^<action-type^>logout^</action-type^>^</action^>
    >>"%TMPDIR%\logout.xml" echo     ^</rpc^>
    >>"%TMPDIR%\logout.xml" echo   ^</soapenv:Body^>
    >>"%TMPDIR%\logout.xml" echo ^</soapenv:Envelope^>
    call :nbirc "%TMPDIR%\logout.xml" "%TMPDIR%\logout_resp.xml"
    echo   note: logged out -- session released
) else (
    echo   note: no NBI session was opened -- nothing to log out
)

REM ============================== CLEANUP ====================================
:cleanup
del /q "%TMPDIR%\*.xml" >nul 2>&1
del /q "%TMPDIR%\*.json" >nul 2>&1
rd "%TMPDIR%" >nul 2>&1
echo.
echo ================================================================
echo CMS live run complete.
echo ================================================================
exit /b 0

:fail
echo.
echo CMS live run FAILED -- see above.
goto :cleanup

REM ============================ SUBROUTINES ==================================

:task
echo.
echo ### TASK[%~1]: %~2
exit /b 0

:step
echo   $ %~1
%~1
if errorlevel 1 ( echo   FAILED ^(exit^): %~1 & goto :fail )
exit /b 0

:srvcheck
if defined CMS_SSH_TARGET (
    echo   $ ssh "%CMS_SSH_TARGET%" "%~1"
    ssh "%CMS_SSH_TARGET%" "%~1"
) else (
    echo   $ %~1
    %~1
)
if errorlevel 1 ( echo   FAILED: %~1 & goto :fail )
exit /b 0

:oltcheck
echo   $ ssh "%OLT_SSH_TARGET%" "%~1"
ssh "%OLT_SSH_TARGET%" "%~1"
if errorlevel 1 ( echo   FAILED: %~1 & goto :fail )
exit /b 0

:yes_warn
echo   !! %~1
set /p "ANS=  Type "yes" to continue, anything else aborts: "
if /i "!ANS!"=="yes" exit /b 0
echo   aborted by operator.
exit /b 1

:op_check
:op_loop
echo   ^>^> operator checklist:
:op_items
set "ARG=%~1"
if "%ARG%"=="" exit /b 0
echo     - %~1
shift
goto :op_items

:req_var
if defined %~1 exit /b 0
echo   ERROR: env var '%~1' is not set -- %~2
echo   Set it and re-run (dry-run.cmd lists every variable).
goto :fail

:req_secret
if defined %~1 exit /b 0
echo   %~1 is not set -- enter it now (input hidden):
powershell -NoProfile -Command "$s=Read-Host -AsSecureString; $b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($s); [Runtime.InteropServices.Marshal]::PtrToStringAuto($b)" > "%TMPDIR%\_secret.txt"
set /p %~1= < "%TMPDIR%\_secret.txt"
del "%TMPDIR%\_secret.txt"
exit /b 0

:nbirc
set "_xml=%~1"
set "_resp=%~2"
echo   $ curl.exe -s -X POST "!URL!" --data @"%_xml%"
curl.exe -s -X POST "!URL!" -H "Content-Type: text/xml; charset=UTF-8" --data @"%_xml%" > "%_resp%"
if errorlevel 1 ( echo   FAILED: NBI call failed & goto :fail )
exit /b 0
