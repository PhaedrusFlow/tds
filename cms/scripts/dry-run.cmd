@echo off
REM ============================================================================
REM dry-run.cmd -- verbose dry-run of every documented Calix CMS task.
REM
REM Walks every CLI procedure documented across cms/guides/*.md (CMS NBI/SOAP,
REM SMx REST, EXOS EWI, AXOS OLT, release-notes scenarios, SmartMDU). For each
REM task it prints the exact command(s) that WOULD run (fully quoted), checks
REM prerequisites, and reports a PASS/SKIP verdict. Makes zero changes: no
REM network calls, never prints or touches credentials. GUI/portal/physical
REM steps are narrated as operator steps.
REM
REM REPORT: writes reports\dry-run-cms-<UTC>.md next to this script: summary
REM up top, per-task verdicts, exact commands, and fix hints. The path is
REM printed at the end. Exit 0 = all PASS, exit 1 = at least one SKIP.
REM ============================================================================
setlocal EnableDelayedExpansion

where curl.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: curl.exe not found ^(Windows 10+ ships it^).
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "REPORT_DIR=%SCRIPT_DIR%reports"
if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%" >nul
for /f %%t in ('powershell -NoProfile -Command "(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')"') do set "STAMP=%%t"
for /f %%t in ('powershell -NoProfile -Command "(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')"') do set "NOWUTC=%%t"
set "REPORT=%REPORT_DIR%dry-run-cms-%STAMP%.md"
set "BODY=%REPORT_DIR%.dry-run-body.tmp"
set "SKIPFILE=%REPORT_DIR%.dry-run-skips.tmp"
if exist "%BODY%" del "%BODY%"
if exist "%SKIPFILE%" del "%SKIPFILE%"
set /a PASS_COUNT=0
set /a SKIP_COUNT=0

call :log "# CMS dry-run -- %NOWUTC%"
call :log "# cmd.exe (API calls run from this machine)"

REM ============================ TASK[01] =====================================
REM FLAG: cat /etc/os-release
REM FLAG: docker --version
REM FLAG: docker compose version
REM FLAG: nproc / free -g
REM FLAG: df -h /
REM FLAG: grep -i version /opt/calix/cms/*/release.properties
REM FLAG: bash --version
call :task_begin "01" "CMS pre-upgrade server checks"
call :check_tool_local "ssh" "needed only if CMS_SSH_TARGET is set (remote server checks)"
call :note "server checks run locally, or via ssh when CMS_SSH_TARGET is set"
if defined CMS_SSH_TARGET (
    call :log "  [ok] CMS_SSH_TARGET=!CMS_SSH_TARGET! (server checks go over ssh)"
    set "_pfx=ssh "!CMS_SSH_TARGET!" ""
) else (
    call :note "CMS_SSH_TARGET unset -- running server checks locally (set it to target the CMS server)"
    set "_pfx="
)
call :show_srv "cat /etc/os-release | head -3"
call :show_srv "docker --version; docker compose version"
call :show_srv "nproc; free -g"
call :show_srv "df -h / | tail -1"
call :show_srv "grep -i version /opt/calix/cms/*/release.properties"
call :show_local "bash --version"
call :note "compare the results against the release-notes prerequisites before upgrading"
call :task_end

REM ============================ TASK[02] =====================================
REM FLAG: grep -i version /opt/calix/cms/*/release.properties  (build lookup)
call :task_begin "02" "Determine CMS upgrade path"
call :check_tool_local "ssh" "needed only if CMS_SSH_TARGET is set"
call :note "read-only -- the upgrade path comes from the release-notes path table, keyed off your build"
call :show_srv "grep -i version /opt/calix/cms/*/release.properties"
call :operator "map the reported build to the upgrade-path table in cms/guides/cms-release-notes.md"
call :note "rule from the guide: verify the path BEFORE touching anything; some builds need intermediate hops"
call :task_end

REM ============================ TASK[03] =====================================
call :task_begin "03" "Alarm mismatch triage (operator)"
call :note "scenario from cms-release-notes: alarms disagree between CMS views -- this is a GUI/operator workflow"
call :operator "open the alarm views named in the release-notes scenario and compare counts"
call :operator "note which view disagrees (stale cache vs live poll) before clearing anything"
call :operator "follow the scenario's remediation order; do not bulk-clear alarms to 'fix' a mismatch"
call :note "nothing scriptable here -- the value is the ordered checklist, not commands"
call :task_end

REM ============================ TASK[04] =====================================
REM FLAG: curl -s -X POST <base> -H 'Content-Type: text/xml; charset=UTF-8' --data @<login-xml>
REM FLAG: findstr "<ResultCode>[0-9]*</ResultCode>"
REM FLAG: findstr "<SessionID>[0-9]*</SessionID>"
REM FLAG: curl.exe -s -X POST "http://%CMS_HOST%:18080%NBI_URI%" --data @<login-xml>   (Windows form from the guide)
call :task_begin "04" "NBI authenticate and capture session"
call :check_tool_local "curl.exe" "Windows 10+ ships curl.exe"
call :require_var "CMS_HOST" "set CMS_HOST=<cms-host>"
call :require_var "CMS_USER" "set CMS_USER=<cms-user>"
call :require_secret "CMS_PASS" "set CMS_PASS=<cms-password> (never displayed)"
call :get_or "CMS_HOST" "<cms-host>"
call :get_or "CMS_PORT" "18080"
call :get_or "NBI_URI" "/cms/nbi"
call :note "login creates a server-side session (200-session client limit -- log out when done)"
set "_u=http://!CMS_HOST!:!CMS_PORT!!NBI_URI!"
set "_c=curl.exe -s -X POST "!_u!" -H "Content-Type: text/xml; charset=UTF-8" --data @C:\temp\nbi-login.xml"
call :show_local "%_c%"
call :note "login XML carries <UserName>%%CMS_USER%% and <Password>***hidden***</Password>"
call :show_local "findstr "<ResultCode>[0-9]*</ResultCode>"   # 0 = success"
call :show_local "findstr "<SessionID>[0-9]*</SessionID>"     # capture SESSIONID"
call :note "troubleshooting: ResultCode != 0 -> wrong creds, missing Full CMS Administration privilege, or session limit hit"
call :note "variant (cmd.exe line-continuation form from the guide):"
set "_c2=curl.exe -s -X POST "http://%%CMS_HOST%%:18080%%NBI_URI%%" ^"
call :show_local "%_c2%"
call :show_local "  -H "Content-Type: text/xml; charset=UTF-8" --data @C:\temp\nbi-login.xml"
call :task_end

REM ============================ TASK[05] =====================================
REM FLAG: show-ont by <subscr-id>
REM FLAG: show-ont by <reg-id>
REM FLAG: show-ont by <serno>
call :task_begin "05" "NBI find ONT and read services"
call :check_tool_local "curl.exe" "Windows 10+ ships curl.exe"
call :require_var "CMS_HOST" "set CMS_HOST=<cms-host> (see task 04)"
call :require_var "NODEN" "set NODEN=<cms-network-node> for the rpc nodename attribute"
call :get_or "CMS_HOST" "<cms-host>"
call :get_or "CMS_PORT" "18080"
call :get_or "NBI_URI" "/cms/nbi"
call :note "read-only -- needs the SESSIONID captured in task 04"
set "_u=http://!CMS_HOST!:!CMS_PORT!!NBI_URI!"
set "_c=curl.exe -s -X POST "!_u!" -H "Content-Type: text/xml; charset=UTF-8" --data @C:\temp\nbi-show-ont.xml"
call :show_local "%_c%"
call :note "variant: filter by subscriber ID (fastest 'whose ONT is this'): <subscr-id><subscriber-id></subscr-id>"
call :require_var "SUBSCRIBER_ID" "set SUBSCRIBER_ID=<id> to preview the subscr-id variant"
call :note "variant: filter by registration ID: <reg-id><reg-id-here></reg-id>  (e.g. 7775554444)"
call :require_var "REG_ID" "set REG_ID=<id> to preview the reg-id variant"
call :note "variant: filter by serial number: <serno><serial-number-here></serno>"
call :require_var "ONT_SERIAL" "set ONT_SERIAL=<serial> to preview the serno variant"
call :task_end

REM ============================ TASK[06] =====================================
REM FLAG: edit-config operation=create (data service)
call :task_begin "06" "NBI create data service on GPON ONT"
call :check_tool_local "curl.exe" "Windows 10+ ships curl.exe"
call :require_var "CMS_HOST" "set CMS_HOST=<cms-host> (see task 04)"
call :require_var "NODEN" "set NODEN=<cms-network-node>"
call :get_or "CMS_HOST" "<cms-host>"
call :get_or "CMS_PORT" "18080"
call :get_or "NBI_URI" "/cms/nbi"
call :note "MUTATING -- provisions a data service on the ONT (needs SESSIONID from task 04)"
set "_u=http://!CMS_HOST!:!CMS_PORT!!NBI_URI!"
set "_c=curl.exe -s -X POST "!_u!" -H "Content-Type: text/xml; charset=UTF-8" --data @C:\temp\nbi-create-service.xml"
call :show_local "%_c%"
call :note "payload: <rpc> edit-config with operation=create carrying the GPON data-service parameters"
call :note "verify afterwards with the task-05 show-ont read before closing the ticket"
call :task_end

REM ============================ TASK[07] =====================================
REM FLAG: edit-config operation=delete (unlink old ONT)
REM FLAG: edit-config operation=create (link new ONT)
REM FLAG: set-to-default (factory reset)
call :task_begin "07" "NBI ONT replacement workflow"
call :check_tool_local "curl.exe" "Windows 10+ ships curl.exe"
call :require_var "CMS_HOST" "set CMS_HOST=<cms-host> (see task 04)"
call :require_var "NODEN" "set NODEN=<cms-network-node>"
call :require_var "ONT_SERIAL_OLD" "set ONT_SERIAL_OLD=<old-serial> (ONT being replaced)"
call :require_var "ONT_SERIAL_NEW" "set ONT_SERIAL_NEW=<new-serial> (replacement ONT)"
call :get_or "CMS_HOST" "<cms-host>"
call :get_or "CMS_PORT" "18080"
call :get_or "NBI_URI" "/cms/nbi"
call :note "MUTATING -- unlink old, link new, factory-reset the newcomer"
set "_u=http://!CMS_HOST!:!CMS_PORT!!NBI_URI!"
set "_c=curl.exe -s -X POST "!_u!" --data @C:\temp\nbi-unlink-ont.xml"
call :show_local "%_c%   # operation=delete old ONT"
set "_c=curl.exe -s -X POST "!_u!" --data @C:\temp\nbi-link-ont.xml"
call :show_local "%_c%   # operation=create new ONT"
set "_c=curl.exe -s -X POST "!_u!" --data @C:\temp\nbi-set-to-default.xml"
call :show_local "%_c%   # factory reset"
call :note "order matters: delete -> create -> set-to-default; verify with show-ont after each step"
call :task_end

REM ============================ TASK[08] =====================================
REM FLAG: curl -sk -u <u:p> -D - -o <file> <base>/config/device?limit=50
call :task_begin "08" "SMx one-time sanity check"
call :check_tool_local "curl.exe" "Windows 10+ ships curl.exe"
call :require_var "SMX_HOST" "set SMX_HOST=<smx-host>"
call :require_var "SMX_USER" "set SMX_USER=<smx-user>"
call :require_secret "SMX_PASS" "set SMX_PASS=<smx-password> (never displayed)"
call :get_or "SMX_HOST" "<smx-host>"
call :note "read-only -- HTTPS Basic auth; -k is for self-signed certs on your LAN only"
set "_c=curl.exe -sk -u "%%SMX_USER%%:***hidden***" -D - -o %%TEMP%%\devices.json "https://!SMX_HOST!:18443/rest/v1/config/device?limit=50""
call :show_local "%_c%"
call :note "status codes: 200 = OK, 401 = bad creds, 429 = over the API rate limit (slow down)"
call :note "default page size is 20 -- always check the x-total-count header"
call :task_end

REM ============================ TASK[09] =====================================
REM FLAG: curl -sk -u <u:p> -X POST <base>/ems/subscriber --data @<json>
REM FLAG: curl -sk -u <u:p> <base>/ems/eth-service?filter=customerID=<id>
REM FLAG: curl -sk -u <u:p> -X DELETE <base>/ems/subscriber/org/<org>/account/<name>
call :task_begin "09" "SMx subscriber lifecycle"
call :check_tool_local "curl.exe" "Windows 10+ ships curl.exe"
call :require_var "SMX_HOST" "set SMX_HOST=<smx-host> (see task 08)"
call :require_var "SMX_USER" "set SMX_USER=<smx-user> (see task 08)"
call :require_secret "SMX_PASS" "set SMX_PASS=<smx-password> (see task 08)"
call :require_var "SMX_SUBSCRIBER_JSON" "set SMX_SUBSCRIBER_JSON=C:\path\subscriber.json (name + customId required; orgId 'Calix' recommended)"
call :get_or "SMX_HOST" "<smx-host>"
call :get_or "SMX_SUBSCRIBER_JSON" "C:\path\subscriber.json"
call :note "MUTATING but self-cleaning -- create -> query -> delete"
set "_c=curl.exe -sk -u "%%SMX_USER%%:***hidden***" -X POST "https://!SMX_HOST!:18443/rest/v1/ems/subscriber" -H "Content-Type: application/json" --data @"!SMX_SUBSCRIBER_JSON!""
call :show_local "%_c%   # 201 = created"
set "_c=curl.exe -sk -u "%%SMX_USER%%:***hidden***" "https://!SMX_HOST!:18443/rest/v1/ems/eth-service?filter=customerID=<subscriber-id>""
call :show_local "%_c%"
call :note "filter narrowing: append ' and port=g1 and deviceName=<device>' to scope to one ONT port"
set "_c=curl.exe -sk -u "%%SMX_USER%%:***hidden***" -X DELETE "https://!SMX_HOST!:18443/rest/v1/ems/subscriber/org/<org-id>/account/<account-name>""
call :show_local "%_c%"
call :task_end

REM ============================ TASK[10] =====================================
REM FLAG: curl -sk -u <u:p> -X POST <base>/config/device/<dev>/ont --data @<json>
REM FLAG: curl -sk -u <u:p> <base>/performance/device/<dev>/ont/<id>/status
REM FLAG: curl -sk -u <u:p> <base>/performance/device/<dev>/ont/<id>/port/g1/status
REM FLAG: curl -sk -u <u:p> <base>/config/device/<dev>/ontport?ont-id=<id>&ont-port-id=g1
REM FLAG: curl -sk -u <u:p> -X PUT <base>/config/device/<dev>/ontport/ont-id/<id>/ont-port-id/g1 --data @<json>
REM FLAG: curl -sk -u <u:p> -X DELETE <base>/config/device/<dev>/ont
call :task_begin "10" "SMx ONT lifecycle"
call :check_tool_local "curl.exe" "Windows 10+ ships curl.exe"
call :check_tool_local "jq" "install jq (used to reshape the port object)"
call :require_var "SMX_HOST" "set SMX_HOST=<smx-host> (see task 08)"
call :require_var "SMX_USER" "set SMX_USER=<smx-user> (see task 08)"
call :require_secret "SMX_PASS" "set SMX_PASS=<smx-password> (see task 08)"
call :require_var "SMX_DEVICE" "set SMX_DEVICE=<device-name> (OLT name/IP, or 'virtualOLT')"
call :require_var "SMX_ONT_JSON" "set SMX_ONT_JSON=C:\path\ont.json (serial-number, ont-profile-id, provisioned-pon, subscriber-id)"
call :get_or "SMX_HOST" "<smx-host>"
call :get_or "SMX_ONT_JSON" "C:\path\ont.json"
call :note "MUTATING but self-cleaning -- create -> status -> delete"
set "_c=curl.exe -sk -u "%%SMX_USER%%:***hidden***" -X POST "https://!SMX_HOST!:18443/rest/v1/config/device/<dev>/ont" -H "Content-Type: application/json" --data @"!SMX_ONT_JSON!""
call :show_local "%_c%"
set "_c=curl.exe -sk -u "%%SMX_USER%%:***hidden***" "https://!SMX_HOST!:18443/rest/v1/performance/device/<dev>/ont/<ont-id>/status""
call :show_local "%_c%"
set "_c=curl.exe -sk -u "%%SMX_USER%%:***hidden***" "https://!SMX_HOST!:18443/rest/v1/performance/device/<dev>/ont/<ont-id>/port/g1/status""
call :show_local "%_c%"
call :note "port admin-state change: GET the object first, then PUT the FULL object back (PUT replaces everything)"
set "_c=curl.exe -sk -u "%%SMX_USER%%:***hidden***" "https://!SMX_HOST!:18443/rest/v1/config/device/<dev>/ontport?ont-id=<id>^&ont-port-id=g1""
call :show_local "%_c%"
set "_c=curl.exe -sk -u "%%SMX_USER%%:***hidden***" -X PUT "https://!SMX_HOST!:18443/rest/v1/config/device/<dev>/ontport/ont-id/<id>/ont-port-id/g1" -H "Content-Type: application/json" --data @C:\temp\port.json"
call :show_local "%_c%"
set "_c=curl.exe -sk -u "%%SMX_USER%%:***hidden***" -X DELETE "https://!SMX_HOST!:18443/rest/v1/config/device/<dev>/ont""
call :show_local "%_c%"
call :task_end

REM ============================ TASK[11] =====================================
REM FLAG: curl -sk -u <u:p> -X POST <base>/config/device/<dev>/vlan -d <json>
REM FLAG: POST /ems/profile/class-map
REM FLAG: POST /config/service-template
REM FLAG: POST /ems/profile/policy-map
REM FLAG: POST /ems/service
call :task_begin "11" "SMx VLAN and service provisioning"
call :check_tool_local "curl.exe" "Windows 10+ ships curl.exe"
call :require_var "SMX_HOST" "set SMX_HOST=<smx-host> (see task 08)"
call :require_var "SMX_USER" "set SMX_USER=<smx-user> (see task 08)"
call :require_secret "SMX_PASS" "set SMX_PASS=<smx-password> (see task 08)"
call :require_var "SMX_DEVICE" "set SMX_DEVICE=<device-name>"
call :require_var "VLAN_ID" "set VLAN_ID=<vlan-id>"
call :get_or "SMX_HOST" "<smx-host>"
call :note "MUTATING -- VLAN create, then the service provisioning order:"
set "_c=curl.exe -sk -u "%%SMX_USER%%:***hidden***" -X POST "https://!SMX_HOST!:18443/rest/v1/config/device/<dev>/vlan" -H "Content-Type: application/json" -d "{"""device-name""":"""<dev>""","""vlan-id""":"""<vlan-id>"""}"""
call :show_local "%_c%"
call :note "provisioning order: 1. POST /ems/profile/class-map  2. POST /config/service-template"
call :note "                    3. POST /ems/profile/policy-map  4. POST /ems/service (data/L2/video/voice/BNG)"
call :note "exact JSON bodies vary by service type -- the guide's trick: do it once in the SMx GUI,"
call :note "then run 'tail -F pmaa.log | grep json' on the SMx server and copy the JSON the GUI sent"
call :task_end

REM ============================ TASK[12] =====================================
REM FLAG: curl -s -o NUL -w "EWI HTTP %{http_code}" http://192.168.1.1/
call :task_begin "12" "EXOS Smart Activate pre-flight"
call :check_tool_local "curl.exe" "Windows 10+ ships curl.exe"
call :require_var "BOX_IP" "set BOX_IP=192.168.1.1 (default EWI address)"
call :get_or "BOX_IP" "192.168.1.1"
call :note "read-only -- proves the box answers on the EWI before opening a browser"
set "_c=curl.exe -s -o NUL -w "EWI HTTP %%{http_code}" "http://!BOX_IP!/""
call :show_local "%_c%"
call :operator "with the WAN unplugged, open http://!BOX_IP!/ in a browser and run Smart Activate there"
call :note "no-laptop path: Voice Activate with a butt set on the POTS port (###0)"
call :task_end

REM ============================ TASK[13] =====================================
REM FLAG: ping -n 4 <box>
REM FLAG: curl -s -o NUL -w "EWI: %{http_code}" http://<box>/
call :task_begin "13" "EXOS EWI health check"
call :check_tool_local "ping" "ships with Windows"
call :check_tool_local "curl.exe" "Windows 10+ ships curl.exe"
call :require_var "BOX_IP" "set BOX_IP=192.168.1.1"
call :get_or "BOX_IP" "192.168.1.1"
call :note "read-only -- L3 then HTTP to the box"
call :show_local "ping -n 4 !BOX_IP!"
set "_c=curl.exe -s -o NUL -w "EWI: %%{http_code}" "http://!BOX_IP!/""
call :show_local "%_c%"
call :operator "walk the EWI health pages listed in exos-provisioning.md (GUI -- no CLI equivalent)"
call :note "ongoing management lives in Calix Service Cloud (TR-069) and the CommandIQ app, not the EWI"
call :task_end

REM ============================ TASK[14] =====================================
call :task_begin "14" "EXOS no-solid-green triage (operator)"
call :note "physical/LED workflow from the release notes -- the LED change rewrites first-glance triage"
call :operator "read the LED states against the release-notes LED table (do not assume the old meanings)"
call :operator "if no solid green: check power, then WAN link, then activation state -- in that order"
call :operator "escalate to the EWI/Cloud checks (tasks 12-13) before replacing hardware"
call :note "nothing scriptable -- LEDs are read with eyes, not curl"
call :task_end

REM ============================ TASK[15] =====================================
REM FLAG: ssh <olt> "show info"
REM FLAG: ssh <olt> "show version"
REM FLAG: ssh <olt> "show smx status"
REM FLAG: ssh <olt> "show upgrade status"
call :task_begin "15" "AXOS pre-upgrade verification on OLT"
call :check_tool_local "ssh" "install Win32 OpenSSH (Settings > Apps > Optional features)"
call :require_var "OLT_SSH_TARGET" "set OLT_SSH_TARGET=user@<olt-host>"
call :get_or "OLT_SSH_TARGET" "user@<olt-host>"
call :note "read-only -- upgrade order is load-bearing: SMx >= 26.3.0 BEFORE the AXOS upgrade;"
call :note "EXOS ONT BEFORE the AXOS OLT (integrated Gateway+ONT systems)"
call :show_local "ssh "!OLT_SSH_TARGET!" "show info""
call :show_local "ssh "!OLT_SSH_TARGET!" "show version""
call :show_local "ssh "!OLT_SSH_TARGET!" "show smx status""
call :show_local "ssh "!OLT_SSH_TARGET!" "show upgrade status""
call :note "baseline the upgrade status; note AXOS-80046 (single-card upgrade + <see guide>) before proceeding"
call :task_end

REM ============================ TASK[16] =====================================
REM FLAG: ssh <olt> "show arp"
REM FLAG: ssh <olt> "show ipv6 neighbor"
REM FLAG: ssh <olt> "show ont <id> detail"
REM FLAG: ssh <olt> "show interface pon bandwidth"
call :task_begin "16" "AXOS daily monitoring checks on OLT"
call :check_tool_local "ssh" "install Win32 OpenSSH (Settings > Apps > Optional features)"
call :require_var "OLT_SSH_TARGET" "set OLT_SSH_TARGET=user@<olt-host>"
call :require_var "ONT_ID_NUM" "set ONT_ID_NUM=<ont-id>"
call :get_or "OLT_SSH_TARGET" "user@<olt-host>"
call :get_or "ONT_ID_NUM" "<ont-id>"
call :note "read-only -- behavior changes after R26.3: show arp / show ipv6 neighbor now hide"
call :note "delegated-prefix/framed-route entries; show ont <id> detail has a new max-tcont-count field;"
call :note "'show interface pon bandwidth' now reflects the actual DBA config"
call :show_local "ssh "!OLT_SSH_TARGET!" "show arp""
call :show_local "ssh "!OLT_SSH_TARGET!" "show ipv6 neighbor""
call :show_local "ssh "!OLT_SSH_TARGET!" "show ont !ONT_ID_NUM! detail""
call :show_local "ssh "!OLT_SSH_TARGET!" "show interface pon bandwidth""
call :task_end

REM ============================ TASK[17] =====================================
call :task_begin "17" "EXOS field checks after R26.3 (operator)"
call :note "field workflow from the release notes -- physical checks plus Service Cloud alerts"
call :operator "verify the box checks in to Calix Service Cloud (TR-069) after the upgrade"
call :operator "confirm the subscriber-facing apps (CommandIQ/ProtectIQ/SmartBiz) still pair"
call :operator "review Service Cloud alerts raised by the upgrade before leaving site"
call :note "nothing scriptable -- Cloud portal + physical presence"
call :task_end

REM ============================ TASK[18] =====================================
call :task_begin "18" "AXOS NETCONF notification-drop triage (operator)"
call :note "triage workflow from the release notes: NETCONF get no longer returns defaults without with-defaults"
call :operator "re-run the failing NETCONF get WITH the with-defaults parameter and compare"
call :operator "check whether the 'missing' data was defaults being omitted (expected) vs a real drop"
call :operator "only then escalate -- most reports of this are the behavior change, not a bug"
call :note "nothing scriptable generically -- the rpc payload is site-specific"
call :task_end

REM ============================ TASK[19] =====================================
call :task_begin "19" "SmartMDU deployment readiness (operator)"
call :note "checklist/portal workflow from smartmdu.md -- mostly operator steps by design"
call :operator "walk the SmartMDU deployment checklist in the guide (site survey items first)"
call :operator "confirm the portal shows the property/building objects before hardware goes in"
call :operator "verify the MDU-specific provisioning flow in the portal matches the plan"
call :note "the guide documents no CLI for this flow -- portal + checklist only"
call :task_end

REM ============================ TASK[00] =====================================
REM FLAG: ^<action^>^<action-type^>logout^</action-type^>^</action^>
call :task_begin "00" "NBI logout"
call :check_tool_local "curl.exe" "Windows 10+ ships curl.exe"
call :require_var "CMS_HOST" "set CMS_HOST=<cms-host> (see task 04)"
call :get_or "CMS_PORT" "18080"
call :get_or "NBI_URI" "/cms/nbi"
call :note "closes the server-side session opened in task 04 -- frees one of the 200 client slots"
set "_c=curl.exe -s -X POST "http://!CMS_HOST!:!CMS_PORT!!NBI_URI!" -H "Content-Type: text/xml; charset=UTF-8" --data @C:\temp\nbi-logout.xml"
call :show_local "%_c%"
call :note "payload: rpc message-id=999 carrying action-type logout with the SESSIONID from task 04"
call :note "expect ResultCode 0; the live run performs this automatically at the end"
call :task_end

REM ============================== REPORT =====================================
set /a TOTAL=PASS_COUNT+SKIP_COUNT
> "%REPORT%" echo # Dry-run report: CMS (Calix CMS / AXOS / EXOS / SMx / SmartMDU)
>>"%REPORT%" echo.
>>"%REPORT%" echo Generated (UTC): %NOWUTC%
>>"%REPORT%" echo Script: cms/scripts/dry-run.cmd (cmd.exe)
>>"%REPORT%" echo.
>>"%REPORT%" echo ## Summary
>>"%REPORT%" echo.
>>"%REPORT%" echo - Tasks total: %TOTAL%
>>"%REPORT%" echo - PASS: %PASS_COUNT%
>>"%REPORT%" echo - SKIP: %SKIP_COUNT%
if %SKIP_COUNT% gtr 0 (
    >>"%REPORT%" echo.
    >>"%REPORT%" echo ### Skipped tasks and fix hints
    >>"%REPORT%" echo.
    type "%SKIPFILE%" >> "%REPORT%"
) else (
    >>"%REPORT%" echo - No missing prerequisites. Every task is ready to run.
)
>>"%REPORT%" echo.
>>"%REPORT%" echo ## Per-task detail
type "%BODY%" >> "%REPORT%"
del "%BODY%" 2>nul
del "%SKIPFILE%" 2>nul

echo.
echo ================================================================
echo CMS dry-run complete: %PASS_COUNT% PASS, %SKIP_COUNT% SKIP
echo Report: %REPORT%
echo ================================================================
if %SKIP_COUNT% gtr 0 ( exit /b 1 ) else ( exit /b 0 )

REM ============================ SUBROUTINES ==================================

:log
echo(%~1
echo(%~1>> "%BODY%"
exit /b 0

:note
call :log "  note: %~1"
exit /b 0

:operator
call :log "  operator step: %~1"
exit /b 0

:task_begin
set "CUR_ID=%~1"
set "CUR_NAME=%~2"
set "CUR_SKIP=0"
call :log ""
call :log "### TASK[%CUR_ID%]: %CUR_NAME%"
exit /b 0

:check_tool_local
where "%~1" >nul 2>&1
if errorlevel 1 (
    set "CUR_SKIP=1"
    call :log "  [MISSING] local tool: %~1"
    call :log "            fix: %~2"
    echo - TASK[!CUR_ID!] !CUR_NAME!: missing local tool '%~1' -- %~2>> "%SKIPFILE%"
) else (
    call :log "  [ok] tool present locally: %~1"
)
exit /b 0

:require_var
if defined %~1 (
    call :log "  [ok] %~1=!%~1!"
) else (
    set "CUR_SKIP=1"
    call :log "  [MISSING] env var: %~1"
    call :log "            fix: %~2"
    echo - TASK[!CUR_ID!] !CUR_NAME!: env var '%~1' not set -- %~2>> "%SKIPFILE%"
)
exit /b 0

:require_secret
if defined %~1 (
    call :log "  [ok] %~1 is set (value hidden)"
) else (
    set "CUR_SKIP=1"
    call :log "  [MISSING] secret: %~1 (value never displayed)"
    call :log "            fix: %~2"
    echo - TASK[!CUR_ID!] !CUR_NAME!: secret '%~1' not set -- %~2>> "%SKIPFILE%"
)
exit /b 0

:get_or
if not defined %~1 set "%~1=%~2"
exit /b 0

:show_local
set "_line=  would run: %~1"
call :log "%_line%"
exit /b 0

:show_srv
if defined CMS_SSH_TARGET (
    set "_line=  would run: ssh "!CMS_SSH_TARGET!" "%~1""
) else (
    set "_line=  would run: %~1"
)
call :log "%_line%"
exit /b 0

:task_end
if "%CUR_SKIP%"=="0" (
    call :log "  verdict: PASS"
    set /a PASS_COUNT+=1
) else (
    call :log "  verdict: SKIP (see fix hints above)"
    set /a SKIP_COUNT+=1
)
exit /b 0
