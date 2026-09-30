<#
.SYNOPSIS
    LIVE execution of every documented Calix CMS task (PowerShell).

.DESCRIPTION
    Runs the same task list as dry-run.ps1, in the same order, for real.
    Read-only tasks run straight through. Every mutating step requires you to
    type "yes" before it runs. GUI/portal/physical steps print their checklist
    and pause for confirmation. Fails fast on the first error. Secrets are
    prompted for (masked) when not set, and are never printed.

    Run dry-run.ps1 first and resolve every SKIP before running this.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------ helpers ---

function Invoke-Task {
    param([string]$Id, [string]$Name)
    Write-Host ''
    Write-Host "### TASK[$Id]: $Name"
}

function Invoke-StepLocal {  # run a local command line, fail fast
    param([string]$Cmd)
    Write-Host "  `$ $Cmd"
    $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $Cmd) -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        Write-Host "  FAILED (exit $($proc.ExitCode)): $Cmd"
        exit 1
    }
}

function Request-Confirm {
    param([string]$Warning)
    Write-Host "  !! $Warning"
    $ans = Read-Host '  Type "yes" to continue, anything else aborts'
    if ($ans -ne 'yes') { Write-Host '  aborted by operator.'; exit 1 }
}

function Wait-Operator {
    param([string]$Checklist)
    Write-Host '  >> operator checklist:'
    Write-Host $Checklist
    $ans = Read-Host '  Press Enter when done, or type "skip"'
    if ($ans -eq 'skip') { Write-Host '  skipped by operator.' }
}

function Require-Var {
    param([string]$Name, [string]$Description)
    $val = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($val)) {
        Write-Host "  ERROR: env var '$Name' is not set -- $Description"
        Write-Host '  Set it and re-run (dry-run.ps1 lists every variable).'
        exit 1
    }
    return $val
}

function Require-Secret {
    param([string]$Name)
    $val = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($val)) {
        $sec = Read-Host "  $Name is not set. Enter value" -AsSecureString
        $val = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
        if ([string]::IsNullOrEmpty($val)) { Write-Host "  ERROR: $Name is required."; exit 1 }
    }
    return $val
}

function Get-VarOr {
    param([string]$Name, [string]$Default)
    $val = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($val)) { return $Default }
    return $val
}

function Write-Note {
    param([string]$Text)
    Write-Host "  note: $Text"
}

function Invoke-ServerCheck {  # via ssh when CMS_SSH_TARGET set, else local
    param([string]$Cmd)
    $t = $env:CMS_SSH_TARGET
    if (-not [string]::IsNullOrEmpty($t)) {
        Write-Host "  `$ ssh `"$t`" `"$Cmd`""
        ssh $t $Cmd
        if ($LASTEXITCODE -ne 0) { Write-Host "  FAILED: $Cmd"; exit 1 }
    } else {
        Invoke-StepLocal $Cmd
    }
}

if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    Write-Host 'ERROR: curl.exe not found (Windows 10+ ships it).'
    exit 1
}

$TmpDir = Join-Path $env:TEMP ("cms-run-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
$script:SessionId = ''

function Invoke-NbiRpc {
    param([string]$XmlPath)
    $ch = $env:CMS_HOST; $cp = Get-VarOr 'CMS_PORT' '18080'; $cu = Get-VarOr 'NBI_URI' '/cms/nbi'
    $url = "http://${ch}:${cp}${cu}"
    Write-Host "  `$ curl.exe -s -X POST `"$url`" --data @$XmlPath"
    $resp = & curl.exe -s -X POST $url -H 'Content-Type: text/xml; charset=UTF-8' --data "@$XmlPath"
    if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: NBI call failed'; exit 1 }
    return $resp
}

Write-Host '=================================================================='
Write-Host 'LIVE RUN -- real commands against your Calix environment.'
Write-Host 'Run dry-run.ps1 first and resolve every SKIP before proceeding.'
Write-Host '=================================================================='

# ---------------------------------------------------------------- tasks ---

# TASK[01]: CMS pre-upgrade server checks
Invoke-Task '01' 'CMS pre-upgrade server checks'
Write-Note "read-only -- via ssh to $($env:CMS_SSH_TARGET) (or locally if unset)"
Invoke-ServerCheck 'cat /etc/os-release | head -3'
Invoke-ServerCheck 'docker --version; docker compose version'
Invoke-ServerCheck 'nproc; free -g'
Invoke-ServerCheck 'df -h / | tail -1'
Invoke-ServerCheck 'grep -i version /opt/calix/cms/*/release.properties'
Invoke-StepLocal 'bash --version'

# TASK[02]: Determine CMS upgrade path
Invoke-Task '02' 'Determine CMS upgrade path'
Write-Note 'read-only -- report your build, then map it in the release-notes path table'
Invoke-ServerCheck 'grep -i version /opt/calix/cms/*/release.properties'
Wait-Operator @'
  - map the build above to the upgrade-path table in cms/guides/cms-release-notes.md
  - confirm whether your build needs intermediate hops before the target release
'@

# TASK[03]: Alarm mismatch triage (operator)
Invoke-Task '03' 'Alarm mismatch triage (operator)'
Wait-Operator @'
  - open the alarm views named in the release-notes scenario and compare counts
  - note which view disagrees (stale cache vs live poll) before clearing anything
  - follow the scenario's remediation order; do not bulk-clear alarms to 'fix' a mismatch
'@

# TASK[04]: NBI authenticate and capture session
Invoke-Task '04' 'NBI authenticate and capture session'
$ch = Require-Var 'CMS_HOST' 'CMS_HOST=<cms-host>'
$cuUser = Require-Var 'CMS_USER' 'CMS_USER=<cms-user>'
$cuPass = Require-Secret 'CMS_PASS'
Write-Note 'login creates a server-side session (200-session limit -- we log out at the end)'
$loginXml = Join-Path $TmpDir 'nbi-login.xml'
@"
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
  <soapenv:Body>
    <auth message-id="1">
      <login>
        <UserName>$cuUser</UserName>
        <Password>$cuPass</Password>
      </login>
    </auth>
  </soapenv:Body>
</soapenv:Envelope>
"@ | Set-Content -Path $loginXml -Encoding UTF8
$cuPass = $null
$resp = Invoke-NbiRpc $loginXml
if ($resp -match '<ResultCode>(\d+)</ResultCode>') { Write-Host "  ResultCode=$($Matches[1])" }
if ($resp -match '<SessionID>(\d+)</SessionID>') {
    $script:SessionId = $Matches[1]
    Write-Note 'authenticated -- SessionID captured (hidden)'
} else {
    Write-Host '  ERROR: no SessionID in the login response.'
    if ($resp -match '<ResultMessage>([^<]*)</ResultMessage>') { Write-Host "  $($Matches[1])" }
    Write-Host '  Check credentials, Full CMS Administration privilege, and the 200-session limit.'
    exit 1
}

# TASK[05]: NBI find ONT and read services
Invoke-Task '05' 'NBI find ONT and read services'
$noden = Require-Var 'NODEN' 'NODEN=<cms-network-node>'
Write-Note 'read-only'
$filter = ''
if ($env:SUBSCRIBER_ID) { $filter = "<subscr-id>$env:SUBSCRIBER_ID</subscr-id>"; Write-Note "filtering by subscriber ID $env:SUBSCRIBER_ID" }
elseif ($env:REG_ID)     { $filter = "<reg-id>$env:REG_ID</reg-id>"; Write-Note 'filtering by registration ID' }
elseif ($env:ONT_SERIAL) { $filter = "<serno>$env:ONT_SERIAL</serno>"; Write-Note 'filtering by serial number' }
else { Write-Note 'no identifier set (SUBSCRIBER_ID/REG_ID/ONT_SERIAL) -- skipping find-ONT' }
if ($filter) {
    $showXml = Join-Path $TmpDir 'nbi-show-ont.xml'
    @"
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://www.w3.org/2003/05/soap-envelope">
  <soapenv:Body>
    <rpc message-id="175" nodename="$noden" username="$cuUser" sessionid="$script:SessionId">
      <action>
        <action-type>show-ont</action-type>
        <action-args>$filter</action-args>
      </action>
    </rpc>
  </soapenv:Body>
</soapenv:Envelope>
"@ | Set-Content -Path $showXml -Encoding UTF8
    $r = Invoke-NbiRpc $showXml
    Write-Host $r
}

# TASK[06]: NBI create data service on GPON ONT
Invoke-Task '06' 'NBI create data service on GPON ONT'
Request-Confirm 'MUTATING: provisions a data service via NBI edit-config (operation=create).'
$createXml = Join-Path $TmpDir 'nbi-create-service.xml'
Write-Note "write the full edit-config rpc XML to $createXml (guide example), then press Enter"
Wait-Operator "  - create $createXml from the guide's edit-config example"
if (Test-Path $createXml) {
    $r = Invoke-NbiRpc $createXml
    Write-Host $r
    Write-Note 'verify with task-05 show-ont before closing the ticket'
} else {
    Write-Note 'no payload provided -- create step skipped'
}

# TASK[07]: NBI ONT replacement workflow
Invoke-Task '07' 'NBI ONT replacement workflow'
$old = Require-Var 'ONT_SERIAL_OLD' 'ONT_SERIAL_OLD=<old-serial>'
$new = Require-Var 'ONT_SERIAL_NEW' 'ONT_SERIAL_NEW=<new-serial>'
Request-Confirm "MUTATING: unlinks ONT $old, links $new, then factory-resets the newcomer."
$unlinkXml = Join-Path $TmpDir 'nbi-unlink-ont.xml'
Write-Note "step 1: unlink old ONT (edit-config operation=delete)"
Wait-Operator "  - write $unlinkXml (delete $old), then press Enter"
if (Test-Path $unlinkXml) { Write-Host (Invoke-NbiRpc $unlinkXml) }
$linkXml = Join-Path $TmpDir 'nbi-link-ont.xml'
Write-Note 'step 2: link new ONT (edit-config operation=create)'
Wait-Operator "  - write $linkXml (create $new), then press Enter"
if (Test-Path $linkXml) { Write-Host (Invoke-NbiRpc $linkXml) }
$resetXml = Join-Path $TmpDir 'nbi-set-to-default.xml'
Write-Note 'step 3: factory reset the new ONT (set-to-default)'
Wait-Operator "  - write $resetXml, then press Enter"
if (Test-Path $resetXml) { Write-Host (Invoke-NbiRpc $resetXml) }
Write-Note 'verify with show-ont after each step'

# TASK[08]: SMx one-time sanity check
Invoke-Task '08' 'SMx one-time sanity check'
$sh = Require-Var 'SMX_HOST' 'SMX_HOST=<smx-host>'
$su = Require-Var 'SMX_USER' 'SMX_USER=<smx-user>'
$sp = Require-Secret 'SMX_PASS'
$SmxBase = "https://${sh}:18443/rest/v1"
Write-Note 'read-only -- HTTPS Basic auth (-k: self-signed LAN certs only)'
$devFile = Join-Path $TmpDir 'devices.json'
Write-Host "  `$ curl.exe -sk -u `"***:***`" -D - -o $devFile `"$SmxBase/config/device?limit=50`""
$headers = & curl.exe -sk -u "${su}:${sp}" -D - -o $devFile "$SmxBase/config/device?limit=50"
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: SMx device list'; exit 1 }
$headers | Select-String -Pattern 'x-total-count' -CaseSensitive:$false
Write-Note '200 = OK, 401 = bad creds, 429 = over the API rate limit (slow down)'
$script:SmxCreds = "${su}:${sp}"

# TASK[09]: SMx subscriber lifecycle
Invoke-Task '09' 'SMx subscriber lifecycle'
$sj = Require-Var 'SMX_SUBSCRIBER_JSON' "SMX_SUBSCRIBER_JSON=C:\path\subscriber.json (name + customId required)"
Request-Confirm 'MUTATING but self-cleaning: creates, queries, then DELETES a subscriber.'
$subResp = Join-Path $TmpDir 'sub-create.json'
Write-Host "  `$ curl.exe -sk -X POST `"$SmxBase/ems/subscriber`" --data @$sj"
& curl.exe -sk -u $script:SmxCreds -X POST "$SmxBase/ems/subscriber" -H 'Content-Type: application/json' --data "@$sj" -o $subResp
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: subscriber create'; exit 1 }
Write-Note "create response saved to $subResp"
$subId = ''
$txt = Get-Content $subResp -Raw
if ($txt -match '"customId"\s*:\s*"([^"]+)"') { $subId = $Matches[1] }
if (-not $subId) { $subId = Read-Host '  could not parse the subscriber id -- paste it' }
Write-Note "querying services for customerID=$subId"
Write-Host "  `$ curl.exe -sk `"$SmxBase/ems/eth-service?filter=customerID=$subId`""
& curl.exe -sk -u $script:SmxCreds "$SmxBase/ems/eth-service?filter=customerID=$subId"
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: eth-service query'; exit 1 }
Write-Host ''
Request-Confirm "cleanup: DELETES the subscriber just created (org 'Calix', account '$subId')."
& curl.exe -sk -u $script:SmxCreds -X DELETE "$SmxBase/ems/subscriber/org/Calix/account/$subId"
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: subscriber delete'; exit 1 }

# TASK[10]: SMx ONT lifecycle
Invoke-Task '10' 'SMx ONT lifecycle'
$dev = Require-Var 'SMX_DEVICE' "SMX_DEVICE=<device-name> (OLT name/IP, or 'virtualOLT')"
$oj = Require-Var 'SMX_ONT_JSON' 'SMX_ONT_JSON=C:\path\ont.json (serial-number, ont-profile-id, provisioned-pon, subscriber-id)'
Request-Confirm "MUTATING but self-cleaning: pre-provisions, checks status, then DELETES an ONT on $dev."
$ontResp = Join-Path $TmpDir 'ont-create.json'
Write-Host "  `$ curl.exe -sk -X POST `"$SmxBase/config/device/$dev/ont`" --data @$oj"
& curl.exe -sk -u $script:SmxCreds -X POST "$SmxBase/config/device/$dev/ont" -H 'Content-Type: application/json' --data "@$oj" -o $ontResp
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: ONT create'; exit 1 }
$ontId = $env:ONT_ID
if (-not $ontId) { $ontId = Read-Host '  paste the ONT id from the create response' }
Write-Note 'ONT status:'
& curl.exe -sk -u $script:SmxCreds "$SmxBase/performance/device/$dev/ont/$ontId/status"
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: ONT status'; exit 1 }
Write-Host ''
Write-Note 'ONT port g1 status:'
& curl.exe -sk -u $script:SmxCreds "$SmxBase/performance/device/$dev/ont/$ontId/port/g1/status"
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: ONT port status'; exit 1 }
Write-Host ''
Write-Note 'port admin-state change: GET the full object first (PUT replaces the entire resource)'
$portGet = Join-Path $TmpDir 'port-get.json'
$portPut = Join-Path $TmpDir 'port.json'
& curl.exe -sk -u $script:SmxCreds "$SmxBase/config/device/$dev/ontport?ont-id=$ontId&ont-port-id=g1" -o $portGet
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: ontport GET'; exit 1 }
if (Get-Command jq -ErrorAction SilentlyContinue) {
    & jq '.admin-status = "up"' $portGet | Set-Content -Path $portPut -Encoding UTF8
    Request-Confirm "MUTATING: sets ONT $ontId port g1 admin-status to up (full-object PUT)."
    & curl.exe -sk -u $script:SmxCreds -X PUT "$SmxBase/config/device/$dev/ontport/ont-id/$ontId/ont-port-id/g1" -H 'Content-Type: application/json' --data "@$portPut"
    if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: ontport PUT'; exit 1 }
} else {
    Write-Note 'jq not found -- skipping the port admin-state PUT (install jq to enable)'
}
Request-Confirm "cleanup: DELETES the ONT just created on $dev."
& curl.exe -sk -u $script:SmxCreds -X DELETE "$SmxBase/config/device/$dev/ont"
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: ONT delete'; exit 1 }

# TASK[11]: SMx VLAN and service provisioning
Invoke-Task '11' 'SMx VLAN and service provisioning'
$vlan = Require-Var 'VLAN_ID' 'VLAN_ID=<vlan-id>'
Request-Confirm "MUTATING: creates VLAN $vlan on $dev."
$vlanBody = "{`"device-name`":`"$dev`",`"vlan-id`":`"$vlan`"}"
& curl.exe -sk -u $script:SmxCreds -X POST "$SmxBase/config/device/$dev/vlan" -H 'Content-Type: application/json' -d $vlanBody
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: VLAN create'; exit 1 }
Write-Host ''
Write-Note 'service provisioning order: 1. POST /ems/profile/class-map  2. POST /config/service-template'
Write-Note '                            3. POST /ems/profile/policy-map   4. POST /ems/service'
Wait-Operator @'
  - for exact service JSON: do it once in the SMx GUI, then on the SMx server run
    'tail -F pmaa.log | grep json' and copy the JSON the GUI sent
'@

# TASK[12]: EXOS Smart Activate pre-flight
Invoke-Task '12' 'EXOS Smart Activate pre-flight'
$box = Get-VarOr 'BOX_IP' '192.168.1.1'
Write-Note 'read-only'
Write-Host "  `$ curl.exe -s -o NUL -w `"EWI HTTP %{http_code}`" `"http://${box}/`""
& curl.exe -s -o NUL -w 'EWI HTTP %{http_code}`n' "http://${box}/"
Write-Host ''
Wait-Operator @"
  - with the WAN unplugged, open http://${box}/ in a browser and run Smart Activate
  - no laptop? Voice Activate with a butt set on the POTS port (###0)
"@

# TASK[13]: EXOS EWI health check
Invoke-Task '13' 'EXOS EWI health check'
$box = Get-VarOr 'BOX_IP' '192.168.1.1'
Write-Note 'read-only'
Invoke-StepLocal "ping -n 4 $box"
Write-Host "  `$ curl.exe -s -o NUL -w `"EWI: %{http_code}`" `"http://${box}/`""
& curl.exe -s -o NUL -w 'EWI: %{http_code}`n' "http://${box}/"
Write-Host ''
Wait-Operator '  - walk the EWI health pages listed in exos-provisioning.md (GUI -- no CLI equivalent)'
Write-Note 'ongoing management lives in Calix Service Cloud (TR-069) and the CommandIQ app'

# TASK[14]: EXOS no-solid-green triage (operator)
Invoke-Task '14' 'EXOS no-solid-green triage (operator)'
Wait-Operator @'
  - read the LED states against the release-notes LED table (do not assume the old meanings)
  - if no solid green: check power, then WAN link, then activation state -- in that order
  - escalate to the EWI/Cloud checks (tasks 12-13) before replacing hardware
'@

# TASK[15]: AXOS pre-upgrade verification on OLT
Invoke-Task '15' 'AXOS pre-upgrade verification on OLT'
$olt = Require-Var 'OLT_SSH_TARGET' 'OLT_SSH_TARGET=user@<olt-host>'
Write-Note 'read-only -- upgrade order: SMx >= 26.3.0 BEFORE AXOS; EXOS ONT BEFORE the AXOS OLT'
foreach ($cmd in @('show info', 'show version', 'show smx status', 'show upgrade status')) {
    Write-Host "  `$ ssh `"$olt`" `"$cmd`""
    ssh $olt $cmd
    if ($LASTEXITCODE -ne 0) { Write-Host "  FAILED: $cmd"; exit 1 }
}

# TASK[16]: AXOS daily monitoring checks on OLT
Invoke-Task '16' 'AXOS daily monitoring checks on OLT'
$olt = Require-Var 'OLT_SSH_TARGET' 'OLT_SSH_TARGET=user@<olt-host>'
$oid = Require-Var 'ONT_ID_NUM' 'ONT_ID_NUM=<ont-id>'
Write-Note 'read-only -- post-R26.3 behavior changes noted in the dry-run'
foreach ($cmd in @('show arp', 'show ipv6 neighbor', "show ont $oid detail", 'show interface pon bandwidth')) {
    Write-Host "  `$ ssh `"$olt`" `"$cmd`""
    ssh $olt $cmd
    if ($LASTEXITCODE -ne 0) { Write-Host "  FAILED: $cmd"; exit 1 }
}

# TASK[17]: EXOS field checks after R26.3 (operator)
Invoke-Task '17' 'EXOS field checks after R26.3 (operator)'
Wait-Operator @'
  - verify the box checks in to Calix Service Cloud (TR-069) after the upgrade
  - confirm the subscriber-facing apps (CommandIQ/ProtectIQ/SmartBiz) still pair
  - review Service Cloud alerts raised by the upgrade before leaving site
'@

# TASK[18]: AXOS NETCONF notification-drop triage (operator)
Invoke-Task '18' 'AXOS NETCONF notification-drop triage (operator)'
Wait-Operator @'
  - re-run the failing NETCONF get WITH the with-defaults parameter and compare
  - check whether the 'missing' data was defaults being omitted (expected) vs a real drop
  - only then escalate -- most reports of this are the behavior change, not a bug
'@

# TASK[19]: SmartMDU deployment readiness (operator)
Invoke-Task '19' 'SmartMDU deployment readiness (operator)'
Wait-Operator @'
  - walk the SmartMDU deployment checklist in the guide (site survey items first)
  - confirm the portal shows the property/building objects before hardware goes in
  - verify the MDU-specific provisioning flow in the portal matches the plan
'@

# TASK[00]: NBI logout
Invoke-Task '00' 'NBI logout'
if ($script:SessionId) {
    $logoutXml = Join-Path $TmpDir 'nbi-logout.xml'
    @"
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
  <soapenv:Body>
    <rpc message-id="999" nodename="$noden" username="$cuUser" sessionid="$script:SessionId">
      <action><action-type>logout</action-type></action>
    </rpc>
  </soapenv:Body>
</soapenv:Envelope>
"@ | Set-Content -Path $logoutXml -Encoding UTF8
    $r = Invoke-NbiRpc $logoutXml
    if ($r -match '<ResultCode>(\d+)</ResultCode>') { Write-Host "  ResultCode=$($Matches[1])" }
    Write-Note 'logged out -- session released'
} else {
    Write-Note 'no NBI session was opened -- nothing to log out'
}

Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '================================================================'
Write-Host 'CMS live run complete.'
Write-Host '================================================================'
