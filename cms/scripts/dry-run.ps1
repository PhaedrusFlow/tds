<#
.SYNOPSIS
    Verbose dry-run of every documented Calix CMS task (PowerShell).

.DESCRIPTION
    Walks every CLI procedure documented across cms/guides/*.md (CMS NBI/SOAP,
    SMx REST, EXOS EWI, AXOS OLT, release-notes scenarios, SmartMDU). For each
    task it prints the exact command(s) that WOULD run (fully quoted), checks
    prerequisites, and reports a PASS/SKIP verdict. Makes zero changes: no
    network calls, never prints or touches credentials. GUI/portal/physical
    steps are narrated as operator steps.

.REPORT
    Writes reports/dry-run-cms-<UTC>.md next to this script: summary up top,
    per-task verdicts, exact commands, and fix hints. The path is printed at
    the end. Exit 0 = all PASS, exit 1 = at least one SKIP.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------ helpers ---

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportDir  = Join-Path $ScriptDir 'reports'
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
$Stamp      = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$ReportPath = Join-Path $ReportDir "dry-run-cms-$Stamp.md"
$BodyLines  = New-Object System.Collections.Generic.List[string]

$script:PassCount = 0
$script:SkipCount = 0
$script:SkipDetails = New-Object System.Collections.Generic.List[string]

function Write-Log {
    param([string]$Text)
    Write-Host $Text
    $BodyLines.Add($Text)
}

function Start-Task {
    param([string]$Id, [string]$Name)
    $script:CurId = $Id; $script:CurName = $Name
    $script:CurSkip = New-Object System.Collections.Generic.List[string]
    Write-Log ''
    Write-Log "### TASK[$Id]: $Name"
}

function Test-Tool {
    param([string]$Tool, [string]$Hint)
    if (Get-Command $Tool -ErrorAction SilentlyContinue) {
        Write-Log "  [ok] tool present locally: $Tool"
    } else {
        $script:CurSkip.Add("missing local tool '$Tool' -- $Hint")
        Write-Log "  [MISSING] local tool: $Tool"
        Write-Log "            fix: $Hint"
    }
}

function Require-Var {
    param([string]$Name, [string]$Description)
    $val = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrEmpty($val)) {
        Write-Log "  [ok] $Name='$val'"
    } else {
        $script:CurSkip.Add("env var '$Name' is not set -- $Description")
        Write-Log "  [MISSING] env var: $Name"
        Write-Log "            fix: $Description"
    }
}

function Require-Secret {
    param([string]$Name, [string]$Description)
    $val = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrEmpty($val)) {
        Write-Log "  [ok] $Name is set (value hidden)"
    } else {
        $script:CurSkip.Add("secret '$Name' is not set -- $Description")
        Write-Log "  [MISSING] secret: $Name (value never displayed)"
        Write-Log "            fix: $Description"
    }
}

function Get-VarOr {
    param([string]$Name, [string]$Default)
    $val = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($val)) { return $Default }
    return $val
}

function Show-Run {
    param([string]$Cmd)
    Write-Log "  would run: $Cmd"
}

function Write-Operator {
    param([string]$Text)
    Write-Log "  operator step: $Text"
}

function Write-Note {
    param([string]$Text)
    Write-Log "  note: $Text"
}

function End-Task {
    if ($script:CurSkip.Count -eq 0) {
        Write-Log '  verdict: PASS'
        $script:PassCount++
    } else {
        Write-Log '  verdict: SKIP'
        foreach ($s in $script:CurSkip) { Write-Log "           - $s" }
        $script:SkipCount++
        $script:SkipDetails.Add("TASK[$script:CurId] $script:CurName :: $($script:CurSkip -join '; ')")
    }
}

function Get-ServerCmd {  # server check: via ssh when CMS_SSH_TARGET set, else local
    param([string]$Cmd)
    $t = $env:CMS_SSH_TARGET
    if (-not [string]::IsNullOrEmpty($t)) { return "ssh `"$t`" `"$Cmd`"" }
    return $Cmd
}

Write-Log "# CMS dry-run -- $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
Write-Log '# PowerShell (API calls run from this machine)'

# ---------------------------------------------------------------- tasks ---

# --- TASK[01]: CMS pre-upgrade server checks ---
Start-Task '01' 'CMS pre-upgrade server checks'
# FLAG: cat /etc/os-release
# FLAG: docker --version
# FLAG: docker compose version
# FLAG: nproc / free -g
# FLAG: df -h /
# FLAG: grep -i version /opt/calix/cms/*/release.properties
# FLAG: bash --version
Test-Tool 'ssh' 'needed only if CMS_SSH_TARGET is set (remote server checks)'
Write-Note 'server checks run locally, or via ssh when CMS_SSH_TARGET is set'
if (-not [string]::IsNullOrEmpty($env:CMS_SSH_TARGET)) {
    Write-Log "  [ok] CMS_SSH_TARGET='$env:CMS_SSH_TARGET' (server checks go over ssh)"
} else {
    Write-Note 'CMS_SSH_TARGET unset -- running server checks locally (set it to target the CMS server)'
}
Show-Run (Get-ServerCmd 'cat /etc/os-release | head -3')
Show-Run (Get-ServerCmd 'docker --version; docker compose version')
Show-Run (Get-ServerCmd 'nproc; free -g')
Show-Run (Get-ServerCmd 'df -h / | tail -1')
Show-Run (Get-ServerCmd 'grep -i version /opt/calix/cms/*/release.properties')
Show-Run 'bash --version | head -1'
Write-Note 'compare the results against the release-notes prerequisites before upgrading'
End-Task

# --- TASK[02]: Determine CMS upgrade path ---
Start-Task '02' 'Determine CMS upgrade path'
# FLAG: grep -i version /opt/calix/cms/*/release.properties  (build lookup)
Test-Tool 'ssh' 'needed only if CMS_SSH_TARGET is set'
Write-Note 'read-only -- the upgrade path comes from the release-notes path table, keyed off your build'
Show-Run (Get-ServerCmd 'grep -i version /opt/calix/cms/*/release.properties')
Write-Operator 'map the reported build to the upgrade-path table in cms/guides/cms-release-notes.md'
Write-Note 'rule from the guide: verify the path BEFORE touching anything; some builds need intermediate hops'
End-Task

# --- TASK[03]: Alarm mismatch triage (operator) ---
Start-Task '03' 'Alarm mismatch triage (operator)'
Write-Note 'scenario from cms-release-notes: alarms disagree between CMS views -- this is a GUI/operator workflow'
Write-Operator 'open the alarm views named in the release-notes scenario and compare counts'
Write-Operator 'note which view disagrees (stale cache vs live poll) before clearing anything'
Write-Operator "follow the scenario's remediation order; do not bulk-clear alarms to 'fix' a mismatch"
Write-Note 'nothing scriptable here -- the value is the ordered checklist, not commands'
End-Task

# --- TASK[04]: NBI authenticate and capture session ---
Start-Task '04' 'NBI authenticate and capture session'
# FLAG: curl -s -X POST <base> -H 'Content-Type: text/xml; charset=UTF-8' --data @<login-xml>
# FLAG: grep -o '<ResultCode>[0-9]*</ResultCode>'
# FLAG: grep -o '<SessionID>[0-9]*</SessionID>'
# FLAG: curl.exe -s -X POST "http://<host>:18080<nbi-uri>" --data @<login-xml>   (Windows form from the guide)
Test-Tool 'curl.exe' 'Windows 10+ ships curl.exe'
Require-Var 'CMS_HOST' 'set CMS_HOST=<cms-host>'
Require-Var 'CMS_USER' 'set CMS_USER=<cms-user>'
Require-Secret 'CMS_PASS' 'set CMS_PASS=<cms-password> (never displayed)'
$ch = Get-VarOr 'CMS_HOST' '<cms-host>'
$cp = Get-VarOr 'CMS_PORT' '18080'
$cu = Get-VarOr 'NBI_URI' '/cms/nbi'
Write-Note 'login creates a server-side session (200-session client limit -- log out when done)'
Show-Run "curl.exe -s -X POST `"http://${ch}:${cp}${cu}`" -H `"Content-Type: text/xml; charset=UTF-8`" --data @C:\temp\nbi-login.xml"
Write-Note 'login XML carries <UserName>$CMS_USER</UserName> and <Password>***hidden***</Password>'
Show-Run 'Select-String ''<ResultCode>[0-9]*</ResultCode>''   # 0 = success'
Show-Run 'Select-String ''<SessionID>[0-9]*</SessionID>''     # capture SESSIONID'
Write-Note 'troubleshooting: ResultCode != 0 -> wrong creds, missing Full CMS Administration privilege, or session limit hit'
Write-Note 'variant (cmd.exe line-continuation form from the guide):'
Show-Run 'curl.exe -s -X POST "http://%CMS_HOST%:18080%NBI_URI%" ^'
Show-Run '  -H "Content-Type: text/xml; charset=UTF-8" --data @C:\temp\nbi-login.xml'
End-Task

# --- TASK[05]: NBI find ONT and read services ---
Start-Task '05' 'NBI find ONT and read services'
# FLAG: show-ont by <subscr-id>
# FLAG: show-ont by <reg-id>
# FLAG: show-ont by <serno>
Test-Tool 'curl.exe' 'Windows 10+ ships curl.exe'
Require-Var 'CMS_HOST' 'set CMS_HOST=<cms-host> (see task 04)'
Require-Var 'NODEN' 'set NODEN=<cms-network-node> for the rpc nodename attribute'
$ch = Get-VarOr 'CMS_HOST' '<cms-host>'
$cp = Get-VarOr 'CMS_PORT' '18080'
$cu = Get-VarOr 'NBI_URI' '/cms/nbi'
Write-Note 'read-only -- needs the SESSIONID captured in task 04'
Show-Run "curl.exe -s -X POST `"http://${ch}:${cp}${cu}`" -H `"Content-Type: text/xml; charset=UTF-8`" --data @C:\temp\nbi-show-ont.xml"
Write-Note "variant: filter by subscriber ID (fastest 'whose ONT is this'): <subscr-id><subscriber-id></subscr-id>"
Require-Var 'SUBSCRIBER_ID' 'set SUBSCRIBER_ID=<id> to preview the subscr-id variant'
Write-Note 'variant: filter by registration ID: <reg-id><reg-id-here></reg-id>  (e.g. 7775554444)'
Require-Var 'REG_ID' 'set REG_ID=<id> to preview the reg-id variant'
Write-Note 'variant: filter by serial number: <serno><serial-number-here></serno>'
Require-Var 'ONT_SERIAL' 'set ONT_SERIAL=<serial> to preview the serno variant'
End-Task

# --- TASK[06]: NBI create data service on GPON ONT ---
Start-Task '06' 'NBI create data service on GPON ONT'
# FLAG: edit-config operation=create (data service)
Test-Tool 'curl.exe' 'Windows 10+ ships curl.exe'
Require-Var 'CMS_HOST' 'set CMS_HOST=<cms-host> (see task 04)'
Require-Var 'NODEN' 'set NODEN=<cms-network-node>'
$ch = Get-VarOr 'CMS_HOST' '<cms-host>'
$cp = Get-VarOr 'CMS_PORT' '18080'
$cu = Get-VarOr 'NBI_URI' '/cms/nbi'
Write-Note 'MUTATING -- provisions a data service on the ONT (needs SESSIONID from task 04)'
Show-Run "curl.exe -s -X POST `"http://${ch}:${cp}${cu}`" -H `"Content-Type: text/xml; charset=UTF-8`" --data @C:\temp\nbi-create-service.xml"
Write-Note 'payload: <rpc> edit-config with operation=create carrying the GPON data-service parameters'
Write-Note 'verify afterwards with the task-05 show-ont read before closing the ticket'
End-Task

# --- TASK[07]: NBI ONT replacement workflow ---
Start-Task '07' 'NBI ONT replacement workflow'
# FLAG: edit-config operation=delete (unlink old ONT)
# FLAG: edit-config operation=create (link new ONT)
# FLAG: set-to-default (factory reset)
Test-Tool 'curl.exe' 'Windows 10+ ships curl.exe'
Require-Var 'CMS_HOST' 'set CMS_HOST=<cms-host> (see task 04)'
Require-Var 'NODEN' 'set NODEN=<cms-network-node>'
Require-Var 'ONT_SERIAL_OLD' 'set ONT_SERIAL_OLD=<old-serial> (ONT being replaced)'
Require-Var 'ONT_SERIAL_NEW' 'set ONT_SERIAL_NEW=<new-serial> (replacement ONT)'
$ch = Get-VarOr 'CMS_HOST' '<cms-host>'
$cp = Get-VarOr 'CMS_PORT' '18080'
$cu = Get-VarOr 'NBI_URI' '/cms/nbi'
Write-Note 'MUTATING -- unlink old, link new, factory-reset the newcomer'
Show-Run "curl.exe -s -X POST `"http://${ch}:${cp}${cu}`" --data @C:\temp\nbi-unlink-ont.xml   # operation=delete old ONT"
Show-Run "curl.exe -s -X POST `"http://${ch}:${cp}${cu}`" --data @C:\temp\nbi-link-ont.xml     # operation=create new ONT"
Show-Run "curl.exe -s -X POST `"http://${ch}:${cp}${cu}`" --data @C:\temp\nbi-set-to-default.xml  # factory reset"
Write-Note 'order matters: delete -> create -> set-to-default; verify with show-ont after each step'
End-Task

# --- TASK[08]: SMx one-time sanity check ---
Start-Task '08' 'SMx one-time sanity check'
# FLAG: curl -sk -u <u:p> -D - -o <file> <base>/config/device?limit=50
Test-Tool 'curl.exe' 'Windows 10+ ships curl.exe'
Require-Var 'SMX_HOST' 'set SMX_HOST=<smx-host>'
Require-Var 'SMX_USER' 'set SMX_USER=<smx-user>'
Require-Secret 'SMX_PASS' 'set SMX_PASS=<smx-password> (never displayed)'
$sh = Get-VarOr 'SMX_HOST' '<smx-host>'
Write-Note 'read-only -- HTTPS Basic auth; -k is for self-signed certs on your LAN only'
Show-Run "curl.exe -sk -u `"`$env:SMX_USER`:***hidden***`" -D - -o `$env:TEMP\devices.json `"https://${sh}:18443/rest/v1/config/device?limit=50`""
Write-Note 'status codes: 200 = OK, 401 = bad creds, 429 = over the API rate limit (slow down)'
Write-Note 'default page size is 20 -- always check the x-total-count header'
End-Task

# --- TASK[09]: SMx subscriber lifecycle ---
Start-Task '09' 'SMx subscriber lifecycle'
# FLAG: curl -sk -u <u:p> -X POST <base>/ems/subscriber --data @<json>
# FLAG: curl -sk -u <u:p> <base>/ems/eth-service?filter=customerID=<id>
# FLAG: curl -sk -u <u:p> -X DELETE <base>/ems/subscriber/org/<org>/account/<name>
Test-Tool 'curl.exe' 'Windows 10+ ships curl.exe'
Require-Var 'SMX_HOST' 'set SMX_HOST=<smx-host> (see task 08)'
Require-Var 'SMX_USER' 'set SMX_USER=<smx-user> (see task 08)'
Require-Secret 'SMX_PASS' 'set SMX_PASS=<smx-password> (see task 08)'
Require-Var 'SMX_SUBSCRIBER_JSON' "set SMX_SUBSCRIBER_JSON=C:\path\subscriber.json (name + customId required; orgId 'Calix' recommended)"
$sh = Get-VarOr 'SMX_HOST' '<smx-host>'
$sj = Get-VarOr 'SMX_SUBSCRIBER_JSON' 'C:\path\subscriber.json'
Write-Note 'MUTATING but self-cleaning -- create -> query -> delete'
Show-Run "curl.exe -sk -u `"`$env:SMX_USER`:***hidden***`" -X POST `"https://${sh}:18443/rest/v1/ems/subscriber`" -H `"Content-Type: application/json`" --data `@`"$sj`"   # 201 = created"
Show-Run "curl.exe -sk -u `"`$env:SMX_USER`:***hidden***`" `"https://${sh}:18443/rest/v1/ems/eth-service?filter=customerID=<subscriber-id>`""
Write-Note "filter narrowing: append ' and port=g1 and deviceName=<device>' to scope to one ONT port"
Show-Run "curl.exe -sk -u `"`$env:SMX_USER`:***hidden***`" -X DELETE `"https://${sh}:18443/rest/v1/ems/subscriber/org/<org-id>/account/<account-name>`""
End-Task

# --- TASK[10]: SMx ONT lifecycle ---
Start-Task '10' 'SMx ONT lifecycle'
# FLAG: curl -sk -u <u:p> -X POST <base>/config/device/<dev>/ont --data @<json>
# FLAG: curl -sk -u <u:p> <base>/performance/device/<dev>/ont/<id>/status
# FLAG: curl -sk -u <u:p> <base>/performance/device/<dev>/ont/<id>/port/g1/status
# FLAG: curl -sk -u <u:p> <base>/config/device/<dev>/ontport?ont-id=<id>&ont-port-id=g1
# FLAG: curl -sk -u <u:p> -X PUT <base>/config/device/<dev>/ontport/ont-id/<id>/ont-port-id/g1 --data @<json>
# FLAG: curl -sk -u <u:p> -X DELETE <base>/config/device/<dev>/ont
Test-Tool 'curl.exe' 'Windows 10+ ships curl.exe'
Require-Var 'SMX_HOST' 'set SMX_HOST=<smx-host> (see task 08)'
Require-Var 'SMX_USER' 'set SMX_USER=<smx-user> (see task 08)'
Require-Secret 'SMX_PASS' 'set SMX_PASS=<smx-password> (see task 08)'
Require-Var 'SMX_DEVICE' "set SMX_DEVICE=<device-name> (OLT name/IP, or 'virtualOLT')"
Require-Var 'SMX_ONT_JSON' 'set SMX_ONT_JSON=C:\path\ont.json (serial-number, ont-profile-id, provisioned-pon, subscriber-id)'
$sh = Get-VarOr 'SMX_HOST' '<smx-host>'
$oj = Get-VarOr 'SMX_ONT_JSON' 'C:\path\ont.json'
Write-Note 'MUTATING but self-cleaning -- create -> status -> delete'
Show-Run "curl.exe -sk -u `"`$env:SMX_USER`:***hidden***`" -X POST `"https://${sh}:18443/rest/v1/config/device/<dev>/ont`" -H `"Content-Type: application/json`" --data `@`"$oj`""
Show-Run "curl.exe -sk -u `"`$env:SMX_USER`:***hidden***`" `"https://${sh}:18443/rest/v1/performance/device/<dev>/ont/<ont-id>/status`""
Show-Run "curl.exe -sk -u `"`$env:SMX_USER`:***hidden***`" `"https://${sh}:18443/rest/v1/performance/device/<dev>/ont/<ont-id>/port/g1/status`""
Write-Note 'port admin-state change: GET the object first, then PUT the FULL object back (PUT replaces everything)'
Show-Run "curl.exe -sk -u `"`$env:SMX_USER`:***hidden***`" `"https://${sh}:18443/rest/v1/config/device/<dev>/ontport?ont-id=<id>&ont-port-id=g1`""
Show-Run "curl.exe -sk -u `"`$env:SMX_USER`:***hidden***`" -X PUT `"https://${sh}:18443/rest/v1/config/device/<dev>/ontport/ont-id/<id>/ont-port-id/g1`" -H `"Content-Type: application/json`" --data @C:\temp\port.json"
Show-Run "curl.exe -sk -u `"`$env:SMX_USER`:***hidden***`" -X DELETE `"https://${sh}:18443/rest/v1/config/device/<dev>/ont`""
End-Task

# --- TASK[11]: SMx VLAN and service provisioning ---
Start-Task '11' 'SMx VLAN and service provisioning'
# FLAG: curl -sk -u <u:p> -X POST <base>/config/device/<dev>/vlan -d <json>
# FLAG: POST /ems/profile/class-map
# FLAG: POST /config/service-template
# FLAG: POST /ems/profile/policy-map
# FLAG: POST /ems/service
Test-Tool 'curl.exe' 'Windows 10+ ships curl.exe'
Require-Var 'SMX_HOST' 'set SMX_HOST=<smx-host> (see task 08)'
Require-Var 'SMX_USER' 'set SMX_USER=<smx-user> (see task 08)'
Require-Secret 'SMX_PASS' 'set SMX_PASS=<smx-password> (see task 08)'
Require-Var 'SMX_DEVICE' 'set SMX_DEVICE=<device-name>'
Require-Var 'VLAN_ID' 'set VLAN_ID=<vlan-id>'
$sh = Get-VarOr 'SMX_HOST' '<smx-host>'
Write-Note 'MUTATING -- VLAN create, then the service provisioning order:'
Show-Run "curl.exe -sk -u `"`$env:SMX_USER`:***hidden***`" -X POST `"https://${sh}:18443/rest/v1/config/device/<dev>/vlan`" -H `"Content-Type: application/json`" -d `"'{`"device-name`":`"<dev>`",`"vlan-id`":`"<vlan-id>`"}`"'"
Write-Note 'provisioning order: 1. POST /ems/profile/class-map  2. POST /config/service-template'
Write-Note '                    3. POST /ems/profile/policy-map  4. POST /ems/service (data/L2/video/voice/BNG)'
Write-Note 'exact JSON bodies vary by service type -- the guide''s trick: do it once in the SMx GUI,'
Write-Note "then run 'tail -F pmaa.log | grep json' on the SMx server and copy the JSON the GUI sent"
End-Task

# --- TASK[12]: EXOS Smart Activate pre-flight ---
Start-Task '12' 'EXOS Smart Activate pre-flight'
# FLAG: curl -s -o NUL -w "EWI HTTP %{http_code}" http://192.168.1.1/
Test-Tool 'curl.exe' 'Windows 10+ ships curl.exe'
Require-Var 'BOX_IP' 'set BOX_IP=192.168.1.1 (default EWI address)'
$box = Get-VarOr 'BOX_IP' '192.168.1.1'
Write-Note 'read-only -- proves the box answers on the EWI before opening a browser'
Show-Run "curl.exe -s -o NUL -w `"EWI HTTP %{http_code}`n`" `"http://${box}/`""
Write-Operator "with the WAN unplugged, open http://${box}/ in a browser and run Smart Activate there"
Write-Note 'no-laptop path: Voice Activate with a butt set on the POTS port (###0)'
End-Task

# --- TASK[13]: EXOS EWI health check ---
Start-Task '13' 'EXOS EWI health check'
# FLAG: ping -n 4 <box>
# FLAG: curl -s -o NUL -w "EWI: %{http_code}" http://<box>/
Test-Tool 'ping' 'ships with Windows'
Test-Tool 'curl.exe' 'Windows 10+ ships curl.exe'
Require-Var 'BOX_IP' 'set BOX_IP=192.168.1.1'
$box = Get-VarOr 'BOX_IP' '192.168.1.1'
Write-Note 'read-only -- L3 then HTTP to the box'
Show-Run "ping -n 4 $box"
Show-Run "curl.exe -s -o NUL -w `"EWI: %{http_code}`n`" `"http://${box}/`""
Write-Operator 'walk the EWI health pages listed in exos-provisioning.md (GUI -- no CLI equivalent)'
Write-Note 'ongoing management lives in Calix Service Cloud (TR-069) and the CommandIQ app, not the EWI'
End-Task

# --- TASK[14]: EXOS no-solid-green triage (operator) ---
Start-Task '14' 'EXOS no-solid-green triage (operator)'
Write-Note 'physical/LED workflow from the release notes -- the LED change rewrites first-glance triage'
Write-Operator 'read the LED states against the release-notes LED table (do not assume the old meanings)'
Write-Operator 'if no solid green: check power, then WAN link, then activation state -- in that order'
Write-Operator 'escalate to the EWI/Cloud checks (tasks 12-13) before replacing hardware'
Write-Note 'nothing scriptable -- LEDs are read with eyes, not curl'
End-Task

# --- TASK[15]: AXOS pre-upgrade verification on OLT ---
Start-Task '15' 'AXOS pre-upgrade verification on OLT'
# FLAG: ssh <olt> "show info"
# FLAG: ssh <olt> "show version"
# FLAG: ssh <olt> "show smx status"
# FLAG: ssh <olt> "show upgrade status"
Test-Tool 'ssh' 'install Win32 OpenSSH (Settings > Apps > Optional features)'
Require-Var 'OLT_SSH_TARGET' 'set OLT_SSH_TARGET=user@<olt-host>'
$olt = Get-VarOr 'OLT_SSH_TARGET' 'user@<olt-host>'
Write-Note 'read-only -- upgrade order is load-bearing: SMx >= 26.3.0 BEFORE the AXOS upgrade;'
Write-Note 'EXOS ONT BEFORE the AXOS OLT (integrated Gateway+ONT systems)'
Show-Run "ssh `"$olt`" `"show info`""
Show-Run "ssh `"$olt`" `"show version`""
Show-Run "ssh `"$olt`" `"show smx status`""
Show-Run "ssh `"$olt`" `"show upgrade status`""
Write-Note 'baseline the upgrade status; note AXOS-80046 (single-card upgrade + <see guide>) before proceeding'
End-Task

# --- TASK[16]: AXOS daily monitoring checks on OLT ---
Start-Task '16' 'AXOS daily monitoring checks on OLT'
# FLAG: ssh <olt> "show arp"
# FLAG: ssh <olt> "show ipv6 neighbor"
# FLAG: ssh <olt> "show ont <id> detail"
# FLAG: ssh <olt> "show interface pon bandwidth"
Test-Tool 'ssh' 'install Win32 OpenSSH (Settings > Apps > Optional features)'
Require-Var 'OLT_SSH_TARGET' 'set OLT_SSH_TARGET=user@<olt-host>'
Require-Var 'ONT_ID_NUM' 'set ONT_ID_NUM=<ont-id>'
$olt = Get-VarOr 'OLT_SSH_TARGET' 'user@<olt-host>'
$oid = Get-VarOr 'ONT_ID_NUM' '<ont-id>'
Write-Note 'read-only -- behavior changes after R26.3: show arp / show ipv6 neighbor now hide'
Write-Note 'delegated-prefix/framed-route entries; show ont <id> detail has a new max-tcont-count field;'
Write-Note "'show interface pon bandwidth' now reflects the actual DBA config"
Show-Run "ssh `"$olt`" `"show arp`""
Show-Run "ssh `"$olt`" `"show ipv6 neighbor`""
Show-Run "ssh `"$olt`" `"show ont $oid detail`""
Show-Run "ssh `"$olt`" `"show interface pon bandwidth`""
End-Task

# --- TASK[17]: EXOS field checks after R26.3 (operator) ---
Start-Task '17' 'EXOS field checks after R26.3 (operator)'
Write-Note 'field workflow from the release notes -- physical checks plus Service Cloud alerts'
Write-Operator 'verify the box checks in to Calix Service Cloud (TR-069) after the upgrade'
Write-Operator 'confirm the subscriber-facing apps (CommandIQ/ProtectIQ/SmartBiz) still pair'
Write-Operator 'review Service Cloud alerts raised by the upgrade before leaving site'
Write-Note 'nothing scriptable -- Cloud portal + physical presence'
End-Task

# --- TASK[18]: AXOS NETCONF notification-drop triage (operator) ---
Start-Task '18' 'AXOS NETCONF notification-drop triage (operator)'
Write-Note "triage workflow from the release notes: NETCONF get no longer returns defaults without with-defaults"
Write-Operator 're-run the failing NETCONF get WITH the with-defaults parameter and compare'
Write-Operator "check whether the 'missing' data was defaults being omitted (expected) vs a real drop"
Write-Operator 'only then escalate -- most reports of this are the behavior change, not a bug'
Write-Note 'nothing scriptable generically -- the rpc payload is site-specific'
End-Task

# --- TASK[19]: SmartMDU deployment readiness (operator) ---
Start-Task '19' 'SmartMDU deployment readiness (operator)'
Write-Note 'checklist/portal workflow from smartmdu.md -- mostly operator steps by design'
Write-Operator 'walk the SmartMDU deployment checklist in the guide (site survey items first)'
Write-Operator 'confirm the portal shows the property/building objects before hardware goes in'
Write-Operator 'verify the MDU-specific provisioning flow in the portal matches the plan'
Write-Note 'the guide documents no CLI for this flow -- portal + checklist only'
End-Task

# --- TASK[00]: NBI logout ---
# FLAG: <action><action-type>logout</action-type></action>
Start-Task '00' 'NBI logout'
Test-Tool 'curl.exe' 'Windows 10+ ships curl.exe'
Require-Var 'CMS_HOST' 'CMS_HOST=<cms-host> (see task 04)'
$Ch   = Get-VarOr 'CMS_HOST' '<cms-host>'
$Port = Get-VarOr 'CMS_PORT' '18080'
$Uri  = Get-VarOr 'NBI_URI' '/cms/nbi'
Write-Note 'closes the server-side session opened in task 04 -- frees one of the 200 client slots'
Show-Run "curl.exe -s -X POST `"http://${Ch}:${Port}${Uri}`" -H `"Content-Type: text/xml; charset=UTF-8`" --data @C:\temp\nbi-logout.xml"
Write-Note 'payload: rpc message-id=999 carrying action-type logout with the SESSIONID from task 04'
Write-Note 'expect ResultCode 0; the live run performs this automatically at the end'
End-Task

# ---------------------------------------------------------------- report ---

$Total = $script:PassCount + $script:SkipCount
$Now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$ReportText = New-Object System.Collections.Generic.List[string]
$ReportText.Add('# Dry-run report: CMS (Calix CMS / AXOS / EXOS / SMx / SmartMDU)')
$ReportText.Add('')
$ReportText.Add("Generated (UTC): $Now")
$ReportText.Add('Script: cms/scripts/dry-run.ps1 (PowerShell)')
$ReportText.Add('')
$ReportText.Add('## Summary')
$ReportText.Add('')
$ReportText.Add("- Tasks total: $Total")
$ReportText.Add("- PASS: $($script:PassCount)")
$ReportText.Add("- SKIP: $($script:SkipCount)")
if ($script:SkipCount -gt 0) {
    $ReportText.Add('')
    $ReportText.Add('### Skipped tasks and fix hints')
    $ReportText.Add('')
    foreach ($d in $script:SkipDetails) { $ReportText.Add("- $d") }
} else {
    $ReportText.Add('- No missing prerequisites. Every task is ready to run.')
}
$ReportText.Add('')
$ReportText.Add('## Per-task detail')
foreach ($l in $BodyLines) { $ReportText.Add($l) }
[System.IO.File]::WriteAllLines($ReportPath, $ReportText)

Write-Host ''
Write-Host '================================================================'
Write-Host "CMS dry-run complete: $($script:PassCount) PASS, $($script:SkipCount) SKIP"
Write-Host "Report: $ReportPath"
Write-Host '================================================================'
if ($script:SkipCount -gt 0) { exit 1 } else { exit 0 }
