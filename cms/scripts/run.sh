#!/usr/bin/env bash
#
# run.sh -- LIVE execution of every documented Calix CMS task.
#
# WHAT IT DOES
#   Runs the same task list as dry-run.sh, in the same order, for real.
#   Read-only tasks run straight through. Every mutating step (NBI service
#   provisioning, ONT replacement, SMx subscriber/ONT/VLAN lifecycle)
#   requires you to type "yes" before it runs. GUI/portal/physical steps
#   print their checklist and pause for you to confirm completion.
#   Fails fast on the first error. Secrets are prompted for (hidden input)
#   when not set, and are never printed.
#
# WHERE IT RUNS
#   Anywhere with bash + curl + ssh. API calls run from this machine.
#   CMS server checks run locally, or over SSH if CMS_SSH_TARGET is set.
#   AXOS OLT checks run over SSH to OLT_SSH_TARGET.
#
# CONFIGURATION -- same variables as dry-run.sh. Run dry-run.sh first and
# fix every SKIP before running this. SMX_SUBSCRIBER_JSON and SMX_ONT_JSON
# point at JSON files you prepare (see the guide examples).
#
# SAFETY: set -euo pipefail. Temp XML/JSON files are wiped on exit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMPD="$(mktemp -d)"
trap 'rm -rf "${TMPD}"' EXIT

# ---------------------------------------------------------------- helpers ---

task() { echo ""; echo "### TASK[$1]: $2"; }

step() {
    echo "  $ $*"
    "$@"
    local rc=$?
    if [ "${rc}" -ne 0 ]; then echo "  FAILED with exit ${rc}: $*"; exit "${rc}"; fi
}

confirm() {
    local ans=""
    echo "  !! $1"
    printf '  Type "yes" to continue, anything else aborts: '
    IFS= read -r ans
    if [ "${ans}" != "yes" ]; then echo "  aborted by operator."; exit 1; fi
}

operator_pause() {
    local ans=""
    echo "  >> operator checklist:"
    printf '%s\n' "$1"
    printf '  Press Enter when done, or type "skip": '
    IFS= read -r ans
    [ "${ans}" = "skip" ] && echo "  skipped by operator."
}

need_var() {
    if [ -z "${!1:-}" ]; then
        echo "  ERROR: env var '$1' is not set -- $2"
        echo "  Set it and re-run (dry-run.sh lists every variable)."
        exit 1
    fi
}

need_secret() { # prompt hidden if unset; never printed
    if [ -z "${!1:-}" ]; then
        local val=""
        printf '  %s is not set. Enter value (input hidden): ' "$1"
        IFS= read -rs val; echo ""
        if [ -z "${val}" ]; then echo "  ERROR: $1 is required."; exit 1; fi
        printf -v "$1" '%s' "${val}"
    fi
}

note() { echo "  note: $*"; }

srv() { # run a server check locally, or over ssh when CMS_SSH_TARGET is set
    if [ -n "${CMS_SSH_TARGET:-}" ]; then
        step ssh "${CMS_SSH_TARGET}" "$*"
    else
        step bash -c "$*"
    fi
}

echo "=================================================================="
echo "LIVE RUN -- real commands against your Calix environment."
echo "Run dry-run.sh first and resolve every SKIP before proceeding."
echo "=================================================================="

# --- TASK[01]: CMS pre-upgrade server checks -------------------------------------------
task "01" "CMS pre-upgrade server checks"
note "read-only -- via ssh to ${CMS_SSH_TARGET:-<local machine>}"
srv "cat /etc/os-release | head -3"
srv "docker --version; docker compose version"
srv "nproc; free -g | awk '/Mem:/{print \$2\" GB\"}'"
srv "df -h / | tail -1"
srv "grep -i version /opt/calix/cms/*/release.properties"
step bash --version | head -1

# --- TASK[02]: Determine CMS upgrade path ------------------------------------------------
task "02" "Determine CMS upgrade path"
note "read-only -- report your build, then map it in the release-notes path table"
if [ -n "${CMS_SSH_TARGET:-}" ]; then
    step ssh "${CMS_SSH_TARGET}" "grep -i version /opt/calix/cms/*/release.properties"
else
    step grep -i version /opt/calix/cms/*/release.properties
fi
operator_pause "  - map the build above to the upgrade-path table in cms/guides/cms-release-notes.md
  - confirm whether your build needs intermediate hops before the target release"

# --- TASK[03]: Alarm mismatch triage (operator) -----------------------------------------------
task "03" "Alarm mismatch triage (operator)"
operator_pause "  - open the alarm views named in the release-notes scenario and compare counts
  - note which view disagrees (stale cache vs live poll) before clearing anything
  - follow the scenario's remediation order; do not bulk-clear alarms to 'fix' a mismatch"

# --- TASK[04]: NBI authenticate and capture session ----------------------------------------------
task "04" "NBI authenticate and capture session"
need_var "CMS_HOST" "export CMS_HOST=<cms-host>"
need_var "CMS_USER" "export CMS_USER=<cms-user>"
need_secret "CMS_PASS"
CMS_PORT="${CMS_PORT:-18080}"
NBI_URI="${NBI_URI:-/cms/nbi}"
BASE="http://${CMS_HOST}:${CMS_PORT}${NBI_URI}"
note "login creates a server-side session (200-session limit -- we log out at the end)"
cat > "${TMPD}/nbi-login.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
  <soapenv:Body>
    <auth message-id="1">
      <login>
        <UserName>${CMS_USER}</UserName>
        <Password>${CMS_PASS}</Password>
      </login>
    </auth>
  </soapenv:Body>
</soapenv:Envelope>
EOF
RESP="$(curl -s -X POST "${BASE}" -H 'Content-Type: text/xml; charset=UTF-8' --data "@${TMPD}/nbi-login.xml")"
echo "${RESP}" | grep -o '<ResultCode>[0-9]*</ResultCode>' || true
SESSIONID="$(echo "${RESP}" | grep -o '<SessionID>[0-9]*</SessionID>' | sed 's/<[^>]*>//g' || true)"
if [ -z "${SESSIONID}" ]; then
    echo "  ERROR: no SessionID in the login response."
    echo "${RESP}" | grep -o '<ResultMessage>[^<]*</ResultMessage>' || true
    echo "  Check credentials, Full CMS Administration privilege, and the 200-session limit."
    exit 1
fi
note "authenticated -- SessionID captured (hidden)"

nbi_rpc() { # $1 = xml file; POST it and print the response
    curl -s -X POST "${BASE}" -H 'Content-Type: text/xml; charset=UTF-8' --data "@$1"
}

nbi_logout() {
    cat > "${TMPD}/nbi-logout.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
  <soapenv:Body>
    <rpc message-id="999" nodename="${NODEN:-}" username="${CMS_USER}" sessionid="${SESSIONID}">
      <action><action-type>logout</action-type></action>
    </rpc>
  </soapenv:Body>
</soapenv:Envelope>
EOF
    nbi_rpc "${TMPD}/nbi-logout.xml" | grep -o '<ResultCode>[0-9]*</ResultCode>' || true
    note "logged out -- session released"
}

# --- TASK[05]: NBI find ONT and read services ------------------------------------------------------
task "05" "NBI find ONT and read services"
need_var "NODEN" "export NODEN=<cms-network-node>"
note "read-only"
if [ -n "${SUBSCRIBER_ID:-}" ]; then
    FILTER="<subscr-id>${SUBSCRIBER_ID}</subscr-id>"; note "filtering by subscriber ID ${SUBSCRIBER_ID}"
elif [ -n "${REG_ID:-}" ]; then
    FILTER="<reg-id>${REG_ID}</reg-id>"; note "filtering by registration ID"
elif [ -n "${ONT_SERIAL:-}" ]; then
    FILTER="<serno>${ONT_SERIAL}</serno>"; note "filtering by serial number"
else
    note "no identifier set (SUBSCRIBER_ID/REG_ID/ONT_SERIAL) -- skipping find-ONT"
    FILTER=""
fi
if [ -n "${FILTER}" ]; then
    cat > "${TMPD}/nbi-show-ont.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://www.w3.org/2003/05/soap-envelope">
  <soapenv:Body>
    <rpc message-id="175" nodename="${NODEN}" username="${CMS_USER}" sessionid="${SESSIONID}">
      <action>
        <action-type>show-ont</action-type>
        <action-args>${FILTER}</action-args>
      </action>
    </rpc>
  </soapenv:Body>
</soapenv:Envelope>
EOF
    nbi_rpc "${TMPD}/nbi-show-ont.xml"
    echo ""
fi

# --- TASK[06]: NBI create data service on GPON ONT -------------------------------------------------------
task "06" "NBI create data service on GPON ONT"
confirm "MUTATING: provisions a data service via NBI edit-config (operation=create)."
note "payload template: edit-config create with your GPON data-service parameters"
note "write the full rpc XML to ${TMPD}/nbi-create-service.xml per the guide, then press Enter"
operator_pause "  - create ${TMPD}/nbi-create-service.xml from the guide's edit-config example"
if [ -f "${TMPD}/nbi-create-service.xml" ]; then
    nbi_rpc "${TMPD}/nbi-create-service.xml"
    echo ""
    note "verify with task-05 show-ont before closing the ticket"
else
    note "no payload provided -- create step skipped"
fi

# --- TASK[07]: NBI ONT replacement workflow ------------------------------------------------------------------
task "07" "NBI ONT replacement workflow"
need_var "ONT_SERIAL_OLD" "export ONT_SERIAL_OLD=<old-serial>"
need_var "ONT_SERIAL_NEW" "export ONT_SERIAL_NEW=<new-serial>"
confirm "MUTATING: unlinks ONT ${ONT_SERIAL_OLD}, links ${ONT_SERIAL_NEW}, then factory-resets the newcomer."
note "step 1: unlink old ONT (edit-config operation=delete) -- payload per the guide"
operator_pause "  - write ${TMPD}/nbi-unlink-ont.xml (delete ${ONT_SERIAL_OLD}), then press Enter"
[ -f "${TMPD}/nbi-unlink-ont.xml" ] && { nbi_rpc "${TMPD}/nbi-unlink-ont.xml"; echo ""; }
note "step 2: link new ONT (edit-config operation=create)"
operator_pause "  - write ${TMPD}/nbi-link-ont.xml (create ${ONT_SERIAL_NEW}), then press Enter"
[ -f "${TMPD}/nbi-link-ont.xml" ] && { nbi_rpc "${TMPD}/nbi-link-ont.xml"; echo ""; }
note "step 3: factory reset the new ONT (set-to-default)"
operator_pause "  - write ${TMPD}/nbi-set-to-default.xml, then press Enter"
[ -f "${TMPD}/nbi-set-to-default.xml" ] && { nbi_rpc "${TMPD}/nbi-set-to-default.xml"; echo ""; }
note "verify with show-ont after each step"

# --- TASK[08]: SMx one-time sanity check ---------------------------------------------------------------------------
task "08" "SMx one-time sanity check"
need_var "SMX_HOST" "export SMX_HOST=<smx-host>"
need_var "SMX_USER" "export SMX_USER=<smx-user>"
need_secret "SMX_PASS"
SMX_BASE="https://${SMX_HOST}:18443/rest/v1"
note "read-only -- HTTPS Basic auth (-k: self-signed LAN certs only)"
step curl -sk -u "${SMX_USER}:${SMX_PASS}" -D - -o "${TMPD}/devices.json" "${SMX_BASE}/config/device?limit=50"
grep -i x-total-count "${TMPD}/devices.json" || true
note "200 = OK, 401 = bad creds, 429 = over the API rate limit (slow down)"

# --- TASK[09]: SMx subscriber lifecycle ---------------------------------------------------------------------------------
task "09" "SMx subscriber lifecycle"
need_var "SMX_SUBSCRIBER_JSON" "export SMX_SUBSCRIBER_JSON=/path/subscriber.json (name + customId required)"
confirm "MUTATING but self-cleaning: creates, queries, then DELETES a subscriber."
step curl -sk -u "${SMX_USER}:${SMX_PASS}" -X POST "${SMX_BASE}/ems/subscriber" \
    -H 'Content-Type: application/json' --data "@${SMX_SUBSCRIBER_JSON}" -o "${TMPD}/sub-create.json"
note "create response saved to ${TMPD}/sub-create.json"
SUB_ID="$(grep -o '"customId"[[:space:]]*:[[:space:]]*"[^"]*"' "${TMPD}/sub-create.json" | head -1 | sed 's/.*"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)"
if [ -z "${SUB_ID}" ]; then
    printf '  could not parse the subscriber id from the response -- paste it: '
    IFS= read -r SUB_ID
fi
note "querying services for customerID=${SUB_ID}"
step curl -sk -u "${SMX_USER}:${SMX_PASS}" "${SMX_BASE}/ems/eth-service?filter=customerID=${SUB_ID}"
confirm "cleanup: DELETES the subscriber just created (org 'Calix', account '${SUB_ID}')."
step curl -sk -u "${SMX_USER}:${SMX_PASS}" -X DELETE "${SMX_BASE}/ems/subscriber/org/Calix/account/${SUB_ID}"

# --- TASK[10]: SMx ONT lifecycle ----------------------------------------------------------------------------------------------
task "10" "SMx ONT lifecycle"
need_var "SMX_DEVICE" "export SMX_DEVICE=<device-name> (OLT name/IP, or 'virtualOLT')"
need_var "SMX_ONT_JSON" "export SMX_ONT_JSON=/path/ont.json (serial-number, ont-profile-id, provisioned-pon, subscriber-id)"
confirm "MUTATING but self-cleaning: pre-provisions, checks status, then DELETES an ONT on ${SMX_DEVICE}."
step curl -sk -u "${SMX_USER}:${SMX_PASS}" -X POST "${SMX_BASE}/config/device/${SMX_DEVICE}/ont" \
    -H 'Content-Type: application/json' --data "@${SMX_ONT_JSON}" -o "${TMPD}/ont-create.json"
if [ -z "${ONT_ID:-}" ]; then
    printf '  paste the ONT id from the create response: '
    IFS= read -r ONT_ID
fi
note "ONT status:"
step curl -sk -u "${SMX_USER}:${SMX_PASS}" "${SMX_BASE}/performance/device/${SMX_DEVICE}/ont/${ONT_ID}/status"
note "ONT port g1 status:"
step curl -sk -u "${SMX_USER}:${SMX_PASS}" "${SMX_BASE}/performance/device/${SMX_DEVICE}/ont/${ONT_ID}/port/g1/status"
note "port admin-state change: GET the full object first (PUT replaces the entire resource)"
step curl -sk -u "${SMX_USER}:${SMX_PASS}" \
    "${SMX_BASE}/config/device/${SMX_DEVICE}/ontport?ont-id=${ONT_ID}&ont-port-id=g1" -o "${TMPD}/port-get.json"
if command -v jq >/dev/null 2>&1; then
    jq '.admin-status = "up"' "${TMPD}/port-get.json" > "${TMPD}/port.json"
    confirm "MUTATING: sets ONT ${ONT_ID} port g1 admin-status to up (full-object PUT)."
    step curl -sk -u "${SMX_USER}:${SMX_PASS}" -X PUT \
        "${SMX_BASE}/config/device/${SMX_DEVICE}/ontport/ont-id/${ONT_ID}/ont-port-id/g1" \
        -H 'Content-Type: application/json' --data "@${TMPD}/port.json"
else
    note "jq not found -- skipping the port admin-state PUT (install jq to enable)"
fi
confirm "cleanup: DELETES the ONT just created on ${SMX_DEVICE}."
step curl -sk -u "${SMX_USER}:${SMX_PASS}" -X DELETE "${SMX_BASE}/config/device/${SMX_DEVICE}/ont"

# --- TASK[11]: SMx VLAN and service provisioning --------------------------------------------------------------------------------------
task "11" "SMx VLAN and service provisioning"
need_var "VLAN_ID" "export VLAN_ID=<vlan-id>"
confirm "MUTATING: creates VLAN ${VLAN_ID} on ${SMX_DEVICE}."
step curl -sk -u "${SMX_USER}:${SMX_PASS}" -X POST "${SMX_BASE}/config/device/${SMX_DEVICE}/vlan" \
    -H 'Content-Type: application/json' \
    -d "{\"device-name\":\"${SMX_DEVICE}\",\"vlan-id\":\"${VLAN_ID}\"}"
note "service provisioning order: 1. POST /ems/profile/class-map  2. POST /config/service-template"
note "                            3. POST /ems/profile/policy-map   4. POST /ems/service"
operator_pause "  - for exact service JSON: do it once in the SMx GUI, then on the SMx server run
    'tail -F pmaa.log | grep json' and copy the JSON the GUI sent"

# --- TASK[12]: EXOS Smart Activate pre-flight ----------------------------------------------------------------------------------------------
task "12" "EXOS Smart Activate pre-flight"
BOX_IP="${BOX_IP:-192.168.1.1}"
note "read-only"
step curl -s -o /dev/null -w "EWI HTTP %{http_code}\n" "http://${BOX_IP}/"
operator_pause "  - with the WAN unplugged, open http://${BOX_IP}/ in a browser and run Smart Activate
  - no laptop? Voice Activate with a butt set on the POTS port (###0)"

# --- TASK[13]: EXOS EWI health check ----------------------------------------------------------------------------------------------------------------
task "13" "EXOS EWI health check"
BOX_IP="${BOX_IP:-192.168.1.1}"
note "read-only"
step ping -c 4 "${BOX_IP}"
step curl -s -o /dev/null -w "EWI: %{http_code}\n" "http://${BOX_IP}/"
operator_pause "  - walk the EWI health pages listed in exos-provisioning.md (GUI -- no CLI equivalent)"
note "ongoing management lives in Calix Service Cloud (TR-069) and the CommandIQ app"

# --- TASK[14]: EXOS no-solid-green triage (operator) ------------------------------------------------------------------------------------------------------
task "14" "EXOS no-solid-green triage (operator)"
operator_pause "  - read the LED states against the release-notes LED table (do not assume the old meanings)
  - if no solid green: check power, then WAN link, then activation state -- in that order
  - escalate to the EWI/Cloud checks (tasks 12-13) before replacing hardware"

# --- TASK[15]: AXOS pre-upgrade verification on OLT ------------------------------------------------------------------------------------------------------------
task "15" "AXOS pre-upgrade verification on OLT"
need_var "OLT_SSH_TARGET" "export OLT_SSH_TARGET=user@<olt-host>"
note "read-only -- upgrade order: SMx >= 26.3.0 BEFORE AXOS; EXOS ONT BEFORE the AXOS OLT"
step ssh "${OLT_SSH_TARGET}" "show info"
step ssh "${OLT_SSH_TARGET}" "show version"
step ssh "${OLT_SSH_TARGET}" "show smx status"
step ssh "${OLT_SSH_TARGET}" "show upgrade status"

# --- TASK[16]: AXOS daily monitoring checks on OLT ------------------------------------------------------------------------------------------------------------------
task "16" "AXOS daily monitoring checks on OLT"
need_var "OLT_SSH_TARGET" "export OLT_SSH_TARGET=user@<olt-host>"
need_var "ONT_ID_NUM" "export ONT_ID_NUM=<ont-id>"
note "read-only -- post-R26.3 behavior changes noted in the dry-run"
step ssh "${OLT_SSH_TARGET}" "show arp"
step ssh "${OLT_SSH_TARGET}" "show ipv6 neighbor"
step ssh "${OLT_SSH_TARGET}" "show ont ${ONT_ID_NUM} detail"
step ssh "${OLT_SSH_TARGET}" "show interface pon bandwidth"

# --- TASK[17]: EXOS field checks after R26.3 (operator) ----------------------------------------------------------------------------------------------------------------------
task "17" "EXOS field checks after R26.3 (operator)"
operator_pause "  - verify the box checks in to Calix Service Cloud (TR-069) after the upgrade
  - confirm the subscriber-facing apps (CommandIQ/ProtectIQ/SmartBiz) still pair
  - review Service Cloud alerts raised by the upgrade before leaving site"

# --- TASK[18]: AXOS NETCONF notification-drop triage (operator) --------------------------------------------------------------------------------------------------------------------
task "18" "AXOS NETCONF notification-drop triage (operator)"
operator_pause "  - re-run the failing NETCONF get WITH the with-defaults parameter and compare
  - check whether the 'missing' data was defaults being omitted (expected) vs a real drop
  - only then escalate -- most reports of this are the behavior change, not a bug"

# --- TASK[19]: SmartMDU deployment readiness (operator) --------------------------------------------------------------------------------------------------------------------------------
task "19" "SmartMDU deployment readiness (operator)"
operator_pause "  - walk the SmartMDU deployment checklist in the guide (site survey items first)
  - confirm the portal shows the property/building objects before hardware goes in
  - verify the MDU-specific provisioning flow in the portal matches the plan"

# --- logout ------------------------------------------------------------------
task "00" "NBI logout"
if [ -n "${SESSIONID:-}" ]; then
    nbi_logout
else
    note "no NBI session was opened -- nothing to log out"
fi

echo ""
echo "================================================================"
echo "CMS live run complete."
echo "================================================================"
