#!/usr/bin/env bash
#
# dry-run.sh -- verbose dry-run of every documented Calix CMS task.
#
# WHAT IT DOES
#   Walks every CLI procedure documented across cms/guides/*.md (CMS NBI/SOAP,
#   SMx REST, EXOS EWI, AXOS OLT, release-notes scenarios, SmartMDU). For each
#   task it prints the exact command(s) that WOULD run (fully quoted), checks
#   that each required tool exists, checks that required environment variables
#   are set (secrets are never printed), and reports a PASS/SKIP verdict.
#
# WHAT IT DOES NOT DO
#   Makes zero changes. No network calls -- not even curl probes. Never prints
#   or touches credentials. GUI/portal/physical steps are narrated as operator
#   steps. Missing prerequisites produce SKIP with a fix hint; exit code is
#   non-zero if anything is missing.
#
# WHERE IT RUNS
#   Anywhere with bash + curl + ssh. API calls (NBI/SMx) run from this machine.
#   CMS server checks (tasks 01-02) run locally, or over SSH if CMS_SSH_TARGET
#   is set (e.g. CMS_SSH_TARGET=user@cms-server). AXOS OLT checks (tasks 15-16)
#   run over SSH to OLT_SSH_TARGET.
#
# CONFIGURATION (all optional; unset values produce SKIP with a hint)
#   CMS_SSH_TARGET   ssh target for the CMS server checks (else local)
#   CMS_HOST CMS_PORT CMS_USER CMS_PASS   NBI SOAP endpoint credentials
#                    (defaults: port 18080; CMS_PASS never displayed)
#   NODEN            CMS network node name for NBI rpc calls
#   SUBSCRIBER_ID REG_ID ONT_SERIAL       identifiers for find-ONT
#   SMX_HOST SMX_USER SMX_PASS             SMx REST credentials (SMX_PASS hidden)
#   SMX_SUBSCRIBER_JSON  path to subscriber JSON for the lifecycle task
#   SMX_DEVICE SMX_ONT_JSON ONT_ID VLAN_ID  SMx ONT/VLAN task inputs
#   OLT_SSH_TARGET   ssh target for the AXOS OLT checks (user@olt-host)
#   ONT_ID_NUM       ONT id for 'show ont <id> detail'
#   BOX_IP           EXOS box address (default 192.168.1.1)
#
# REPORT
#   Writes reports/dry-run-cms-<UTC>.md next to this script: summary up top,
#   per-task verdicts, exact commands, and fix hints. Printed at the end.
#
# EXIT CODE: 0 = every task PASS. 1 = at least one task SKIP.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORT_DIR}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
REPORT="${REPORT_DIR}/dry-run-cms-${STAMP}.md"
BODY="$(mktemp)"

PASS_COUNT=0
SKIP_COUNT=0
declare -a SKIP_DETAILS=()

log()  { printf '%s\n' "$*" | tee -a "${BODY}"; }
rlog() { printf '%s\n' "$*" >> "${BODY}"; }

task_begin() {
    CUR_ID="$1"; CUR_NAME="$2"; CUR_SKIP=()
    log ""
    log "### TASK[${CUR_ID}]: ${CUR_NAME}"
}

check_tool() {
    local where
    if where="$(command -v "$1" 2>/dev/null)"; then
        log "  [ok] tool present: $1 (${where})"
    else
        CUR_SKIP+=("missing tool '$1' -- $2")
        log "  [MISSING] tool: $1"
        log "            fix: $2"
    fi
}

require_var() {
    local val="${!1:-}"
    if [ -n "${val}" ]; then
        log "  [ok] $1='${val}'"
    else
        CUR_SKIP+=("env var '$1' is not set -- $2")
        log "  [MISSING] env var: $1"
        log "            fix: $2"
    fi
}

require_secret() {
    if [ -n "${!1:-}" ]; then
        log "  [ok] $1 is set (value hidden)"
    else
        CUR_SKIP+=("secret '$1' is not set -- $2")
        log "  [MISSING] secret: $1 (value never displayed)"
        log "            fix: $2"
    fi
}

would_run() { log "  would run: $*"; }
operator()  { log "  operator step: $*"; }
note()      { log "  note: $*"; }

task_end() {
    if [ "${#CUR_SKIP[@]}" -eq 0 ]; then
        log "  verdict: PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        log "  verdict: SKIP"
        for s in "${CUR_SKIP[@]}"; do
            log "           - ${s}"
        done
        SKIP_COUNT=$((SKIP_COUNT + 1))
        SKIP_DETAILS+=("TASK[${CUR_ID}] ${CUR_NAME} :: ${CUR_SKIP[*]}")
    fi
}

default_var() {
    if [ -z "${!1:-}" ]; then printf -v "$1" '%s' "$2"; fi
}

# server-side runner: ssh if CMS_SSH_TARGET set, else local
srv() {
    if [ -n "${CMS_SSH_TARGET:-}" ]; then
        printf 'ssh %s "%s"' "${CMS_SSH_TARGET}" "$*"
    else
        printf '%s' "$*"
    fi
}

log "# CMS dry-run -- $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "# host: $(hostname 2>/dev/null || echo unknown)  user: $(id -un 2>/dev/null || echo unknown)"

# --- TASK[01]: CMS pre-upgrade server checks -------------------------------------------
task_begin "01" "CMS pre-upgrade server checks"
# FLAG: cat /etc/os-release
# FLAG: docker --version
# FLAG: docker compose version
# FLAG: nproc / free -g
# FLAG: df -h /
# FLAG: grep -i version /opt/calix/cms/*/release.properties
# FLAG: bash --version
check_tool "ssh" "needed only if CMS_SSH_TARGET is set (remote server checks)"
note "server checks run locally, or via ssh when CMS_SSH_TARGET is set"
if [ -n "${CMS_SSH_TARGET:-}" ]; then
    log "  [ok] CMS_SSH_TARGET='${CMS_SSH_TARGET}' (server checks go over ssh)"
else
    note "CMS_SSH_TARGET unset -- running server checks locally (set it to target the CMS server)"
fi
would_run "$(srv "cat /etc/os-release | head -3")"
would_run "$(srv "docker --version; docker compose version")"
would_run "$(srv "nproc; free -g | awk '/Mem:/{print \$2\" GB\"}'")"
would_run "$(srv "df -h / | tail -1")"
would_run "$(srv "grep -i version /opt/calix/cms/*/release.properties")"
would_run "bash --version | head -1"
note "compare the results against the release-notes prerequisites before upgrading"
task_end

# --- TASK[02]: Determine CMS upgrade path ------------------------------------------------
task_begin "02" "Determine CMS upgrade path"
# FLAG: grep -i version /opt/calix/cms/*/release.properties  (build lookup)
check_tool "ssh" "needed only if CMS_SSH_TARGET is set"
note "read-only -- the upgrade path comes from the release-notes path table, keyed off your build"
would_run "$(srv "grep -i version /opt/calix/cms/*/release.properties 2>/dev/null || grep -ri version /opt/calix/cms/ 2>/dev/null | head -5")"
operator "map the reported build to the upgrade-path table in cms/guides/cms-release-notes.md"
note "rule from the guide: verify the path BEFORE touching anything; some builds need intermediate hops"
task_end

# --- TASK[03]: Alarm mismatch triage (operator) -----------------------------------------------
task_begin "03" "Alarm mismatch triage (operator)"
note "scenario from cms-release-notes: alarms disagree between CMS views -- this is a GUI/operator workflow"
operator "open the alarm views named in the release-notes scenario and compare counts"
operator "note which view disagrees (stale cache vs live poll) before clearing anything"
operator "follow the scenario's remediation order; do not bulk-clear alarms to 'fix' a mismatch"
note "nothing scriptable here -- the value is the ordered checklist, not commands"
task_end

# --- TASK[04]: NBI authenticate and capture session ----------------------------------------------
task_begin "04" "NBI authenticate and capture session"
# FLAG: curl -s -X POST <base> -H 'Content-Type: text/xml; charset=UTF-8' --data @<login-xml>
# FLAG: grep -o '<ResultCode>[0-9]*</ResultCode>'
# FLAG: grep -o '<SessionID>[0-9]*</SessionID>'
check_tool "curl" "install curl"
check_tool "grep" "standard on any distro"
require_var "CMS_HOST" "export CMS_HOST=<cms-host>"
require_var "CMS_USER" "export CMS_USER=<cms-user>"
require_secret "CMS_PASS" "export CMS_PASS=<cms-password> (never displayed)"
default_var CMS_HOST "<cms-host>"
default_var CMS_PORT "18080"
default_var NBI_URI "/cms/nbi"
default_var CMS_USER "<cms-user>"
note "login creates a server-side session (200-session client limit -- log out when done)"
would_run "curl -s -X POST 'http://${CMS_HOST}:${CMS_PORT}${NBI_URI}' -H 'Content-Type: text/xml; charset=UTF-8' --data @/tmp/nbi-login.xml"
note "login XML carries <UserName>\${CMS_USER}</UserName> and <Password>***hidden***</Password>"
would_run "echo \"\$RESP\" | grep -o '<ResultCode>[0-9]*</ResultCode>'   # 0 = success"
would_run "echo \"\$RESP\" | grep -o '<SessionID>[0-9]*</SessionID>' | sed 's/<[^>]*>//g'   # capture SESSIONID"
note "troubleshooting: ResultCode != 0 -> wrong creds, missing Full CMS Administration privilege, or session limit hit"
task_end

# --- TASK[05]: NBI find ONT and read services ------------------------------------------------------
task_begin "05" "NBI find ONT and read services"
# FLAG: show-ont by <subscr-id>
# FLAG: show-ont by <reg-id>
# FLAG: show-ont by <serno>
check_tool "curl" "install curl"
require_var "CMS_HOST" "export CMS_HOST=<cms-host> (see task 04)"
require_var "NODEN" "export NODEN=<cms-network-node> for the rpc nodename attribute"
default_var CMS_HOST "<cms-host>"
default_var CMS_PORT "18080"
default_var NBI_URI "/cms/nbi"
note "read-only -- needs the SESSIONID captured in task 04"
would_run "curl -s -X POST 'http://${CMS_HOST}:${CMS_PORT}${NBI_URI}' -H 'Content-Type: text/xml; charset=UTF-8' --data @/tmp/nbi-show-ont.xml"
note "variant: filter by subscriber ID (fastest 'whose ONT is this'): <subscr-id><subscriber-id></subscr-id>"
require_var "SUBSCRIBER_ID" "export SUBSCRIBER_ID=<id> to preview the subscr-id variant"
note "variant: filter by registration ID: <reg-id><reg-id-here></reg-id>  (e.g. 7775554444)"
require_var "REG_ID" "export REG_ID=<id> to preview the reg-id variant"
note "variant: filter by serial number: <serno><serial-number-here></serno>"
require_var "ONT_SERIAL" "export ONT_SERIAL=<serial> to preview the serno variant"
task_end

# --- TASK[06]: NBI create data service on GPON ONT -------------------------------------------------------
task_begin "06" "NBI create data service on GPON ONT"
# FLAG: edit-config operation=create (data service)
check_tool "curl" "install curl"
require_var "CMS_HOST" "export CMS_HOST=<cms-host> (see task 04)"
require_var "NODEN" "export NODEN=<cms-network-node>"
note "MUTATING -- provisions a data service on the ONT (needs SESSIONID from task 04)"
would_run "curl -s -X POST 'http://${CMS_HOST}:${CMS_PORT}${NBI_URI}' -H 'Content-Type: text/xml; charset=UTF-8' --data @/tmp/nbi-create-service.xml"
note "payload: <rpc> edit-config with operation=create carrying the GPON data-service parameters"
note "verify afterwards with the task-05 show-ont read before closing the ticket"
task_end

# --- TASK[07]: NBI ONT replacement workflow ------------------------------------------------------------------
task_begin "07" "NBI ONT replacement workflow"
# FLAG: edit-config operation=delete (unlink old ONT)
# FLAG: edit-config operation=create (link new ONT)
# FLAG: set-to-default (factory reset)
check_tool "curl" "install curl"
require_var "CMS_HOST" "export CMS_HOST=<cms-host> (see task 04)"
require_var "NODEN" "export NODEN=<cms-network-node>"
require_var "ONT_SERIAL_OLD" "export ONT_SERIAL_OLD=<old-serial> (ONT being replaced)"
require_var "ONT_SERIAL_NEW" "export ONT_SERIAL_NEW=<new-serial> (replacement ONT)"
note "MUTATING -- unlink old, link new, factory-reset the newcomer"
would_run "curl -s -X POST 'http://<cms-host>:<port><nbi-uri>' --data @/tmp/nbi-unlink-ont.xml   # operation=delete old ONT"
would_run "curl -s -X POST 'http://<cms-host>:<port><nbi-uri>' --data @/tmp/nbi-link-ont.xml     # operation=create new ONT"
would_run "curl -s -X POST 'http://<cms-host>:<port><nbi-uri>' --data @/tmp/nbi-set-to-default.xml  # factory reset"
note "order matters: delete -> create -> set-to-default; verify with show-ont after each step"
task_end

# --- TASK[08]: SMx one-time sanity check ---------------------------------------------------------------------------
task_begin "08" "SMx one-time sanity check"
# FLAG: curl -sk -u <u:p> -D - -o /tmp/devices.json <base>/config/device?limit=50
check_tool "curl" "install curl"
require_var "SMX_HOST" "export SMX_HOST=<smx-host>"
require_var "SMX_USER" "export SMX_USER=<smx-user>"
require_secret "SMX_PASS" "export SMX_PASS=<smx-password> (never displayed)"
default_var SMX_HOST "<smx-host>"
note "read-only -- HTTPS Basic auth; -k is for self-signed certs on your LAN only"
would_run "curl -sk -u '\${SMX_USER}:***hidden***' -D - -o /tmp/devices.json 'https://${SMX_HOST}:18443/rest/v1/config/device?limit=50' | grep -i x-total-count"
note "status codes: 200 = OK, 401 = bad creds, 429 = over the API rate limit (slow down)"
note "default page size is 20 -- always check the x-total-count header"
task_end

# --- TASK[09]: SMx subscriber lifecycle ---------------------------------------------------------------------------------
task_begin "09" "SMx subscriber lifecycle"
# FLAG: curl -sk -u <u:p> -X POST <base>/ems/subscriber --data @<json>
# FLAG: curl -sk -u <u:p> <base>/ems/eth-service?filter=customerID=<id>
# FLAG: curl -sk -u <u:p> -X DELETE <base>/ems/subscriber/org/<org>/account/<name>
check_tool "curl" "install curl"
require_var "SMX_HOST" "export SMX_HOST=<smx-host> (see task 08)"
require_var "SMX_USER" "export SMX_USER=<smx-user> (see task 08)"
require_secret "SMX_PASS" "export SMX_PASS=<smx-password> (see task 08)"
require_var "SMX_SUBSCRIBER_JSON" "export SMX_SUBSCRIBER_JSON=/path/subscriber.json (name + customId required; orgId 'Calix' recommended)"
note "MUTATING but self-cleaning -- create -> query -> delete"
would_run "curl -sk -u '\${SMX_USER}:***hidden***' -X POST 'https://<smx-host>:18443/rest/v1/ems/subscriber' -H 'Content-Type: application/json' --data @\${SMX_SUBSCRIBER_JSON}   # 201 = created"
would_run "curl -sk -u '\${SMX_USER}:***hidden***' 'https://<smx-host>:18443/rest/v1/ems/eth-service?filter=customerID=<subscriber-id>'"
note "filter narrowing: append ' and port=g1 and deviceName=<device>' to scope to one ONT port"
would_run "curl -sk -u '\${SMX_USER}:***hidden***' -X DELETE 'https://<smx-host>:18443/rest/v1/ems/subscriber/org/<org-id>/account/<account-name>'"
task_end

# --- TASK[10]: SMx ONT lifecycle ----------------------------------------------------------------------------------------------
task_begin "10" "SMx ONT lifecycle"
# FLAG: curl -sk -u <u:p> -X POST <base>/config/device/<dev>/ont --data @<json>
# FLAG: curl -sk -u <u:p> <base>/performance/device/<dev>/ont/<id>/status
# FLAG: curl -sk -u <u:p> <base>/performance/device/<dev>/ont/<id>/port/g1/status
# FLAG: curl -sk -u <u:p> <base>/config/device/<dev>/ontport?ont-id=<id>&ont-port-id=g1
# FLAG: curl -sk -u <u:p> -X PUT <base>/config/device/<dev>/ontport/ont-id/<id>/ont-port-id/g1 --data @<json>
# FLAG: curl -sk -u <u:p> -X DELETE <base>/config/device/<dev>/ont
check_tool "curl" "install curl"
check_tool "jq" "install jq (used to reshape the port object)"
require_var "SMX_HOST" "export SMX_HOST=<smx-host> (see task 08)"
require_var "SMX_USER" "export SMX_USER=<smx-user> (see task 08)"
require_secret "SMX_PASS" "export SMX_PASS=<smx-password> (see task 08)"
require_var "SMX_DEVICE" "export SMX_DEVICE=<device-name> (OLT name/IP, or 'virtualOLT')"
require_var "SMX_ONT_JSON" "export SMX_ONT_JSON=/path/ont.json (serial-number, ont-profile-id, provisioned-pon, subscriber-id)"
note "MUTATING but self-cleaning -- create -> status -> delete"
would_run "curl -sk -u '\${SMX_USER}:***hidden***' -X POST 'https://<smx-host>:18443/rest/v1/config/device/<dev>/ont' -H 'Content-Type: application/json' --data @\${SMX_ONT_JSON}"
would_run "curl -sk -u '\${SMX_USER}:***hidden***' 'https://<smx-host>:18443/rest/v1/performance/device/<dev>/ont/<ont-id>/status'"
would_run "curl -sk -u '\${SMX_USER}:***hidden***' 'https://<smx-host>:18443/rest/v1/performance/device/<dev>/ont/<ont-id>/port/g1/status'"
note "port admin-state change: GET the object first, then PUT the FULL object back (PUT replaces everything)"
would_run "curl -sk -u '\${SMX_USER}:***hidden***' 'https://<smx-host>:18443/rest/v1/config/device/<dev>/ontport?ont-id=<id>&ont-port-id=g1' | jq '.admin-status = \"up\"' > /tmp/port.json"
would_run "curl -sk -u '\${SMX_USER}:***hidden***' -X PUT 'https://<smx-host>:18443/rest/v1/config/device/<dev>/ontport/ont-id/<id>/ont-port-id/g1' -H 'Content-Type: application/json' --data @/tmp/port.json"
would_run "curl -sk -u '\${SMX_USER}:***hidden***' -X DELETE 'https://<smx-host>:18443/rest/v1/config/device/<dev>/ont'"
task_end

# --- TASK[11]: SMx VLAN and service provisioning --------------------------------------------------------------------------------------
task_begin "11" "SMx VLAN and service provisioning"
# FLAG: curl -sk -u <u:p> -X POST <base>/config/device/<dev>/vlan -d <json>
# FLAG: POST /ems/profile/class-map
# FLAG: POST /config/service-template
# FLAG: POST /ems/profile/policy-map
# FLAG: POST /ems/service
check_tool "curl" "install curl"
require_var "SMX_HOST" "export SMX_HOST=<smx-host> (see task 08)"
require_var "SMX_USER" "export SMX_USER=<smx-user> (see task 08)"
require_secret "SMX_PASS" "export SMX_PASS=<smx-password> (see task 08)"
require_var "SMX_DEVICE" "export SMX_DEVICE=<device-name>"
require_var "VLAN_ID" "export VLAN_ID=<vlan-id>"
note "MUTATING -- VLAN create, then the service provisioning order:"
would_run "curl -sk -u '\${SMX_USER}:***hidden***' -X POST 'https://<smx-host>:18443/rest/v1/config/device/<dev>/vlan' -H 'Content-Type: application/json' -d '{\"device-name\":\"<dev>\",\"vlan-id\":\"<vlan-id>\"}'"
note "provisioning order: 1. POST /ems/profile/class-map  2. POST /config/service-template"
note "                    3. POST /ems/profile/policy-map  4. POST /ems/service (data/L2/video/voice/BNG)"
note "exact JSON bodies vary by service type -- the guide's trick: do it once in the SMx GUI,"
note "then run 'tail -F pmaa.log | grep json' on the SMx server and copy the JSON the GUI sent"
task_end

# --- TASK[12]: EXOS Smart Activate pre-flight ----------------------------------------------------------------------------------------------
task_begin "12" "EXOS Smart Activate pre-flight"
# FLAG: curl -s -o /dev/null -w "EWI HTTP %{http_code}" http://192.168.1.1/
check_tool "curl" "install curl"
require_var "BOX_IP" "export BOX_IP=192.168.1.1 (default EWI address)"
default_var BOX_IP "192.168.1.1"
note "read-only -- proves the box answers on the EWI before opening a browser"
would_run "curl -s -o /dev/null -w 'EWI HTTP %{http_code}\n' 'http://${BOX_IP}/'"
operator "with the WAN unplugged, open http://${BOX_IP}/ in a browser and run Smart Activate there"
note "no-laptop path: Voice Activate with a butt set on the POTS port (###0)"
task_end

# --- TASK[13]: EXOS EWI health check ----------------------------------------------------------------------------------------------------------------
task_begin "13" "EXOS EWI health check"
# FLAG: ping -c 4 <box>
# FLAG: curl -s -o /dev/null -w "EWI: %{http_code}" http://<box>/
check_tool "ping" "standard on any distro"
check_tool "curl" "install curl"
require_var "BOX_IP" "export BOX_IP=192.168.1.1"
default_var BOX_IP "192.168.1.1"
note "read-only -- L3 then HTTP to the box"
would_run "ping -c 4 '${BOX_IP}'"
would_run "curl -s -o /dev/null -w 'EWI: %{http_code}\n' 'http://${BOX_IP}/'"
operator "walk the EWI health pages listed in exos-provisioning.md (GUI -- no CLI equivalent)"
note "ongoing management lives in Calix Service Cloud (TR-069) and the CommandIQ app, not the EWI"
task_end

# --- TASK[14]: EXOS no-solid-green triage (operator) ------------------------------------------------------------------------------------------------------
task_begin "14" "EXOS no-solid-green triage (operator)"
note "physical/LED workflow from the release notes -- the LED change rewrites first-glance triage"
operator "read the LED states against the release-notes LED table (do not assume the old meanings)"
operator "if no solid green: check power, then WAN link, then activation state -- in that order"
operator "escalate to the EWI/Cloud checks (tasks 12-13) before replacing hardware"
note "nothing scriptable -- LEDs are read with eyes, not curl"
task_end

# --- TASK[15]: AXOS pre-upgrade verification on OLT ------------------------------------------------------------------------------------------------------------
task_begin "15" "AXOS pre-upgrade verification on OLT"
# FLAG: ssh <olt> "show info"
# FLAG: ssh <olt> "show version"
# FLAG: ssh <olt> "show smx status"
# FLAG: ssh <olt> "show upgrade status"
check_tool "ssh" "install openssh client"
require_var "OLT_SSH_TARGET" "export OLT_SSH_TARGET=user@<olt-host>"
note "read-only -- upgrade order is load-bearing: SMx >= 26.3.0 BEFORE the AXOS upgrade;"
note "EXOS ONT BEFORE the AXOS OLT (integrated Gateway+ONT systems)"
would_run "ssh '${OLT_SSH_TARGET:-user@<olt-host>}' 'show info'"
would_run "ssh '${OLT_SSH_TARGET:-user@<olt-host>}' 'show version'"
would_run "ssh '${OLT_SSH_TARGET:-user@<olt-host>}' 'show smx status'"
would_run "ssh '${OLT_SSH_TARGET:-user@<olt-host>}' 'show upgrade status'"
note "baseline the upgrade status; note AXOS-80046 (single-card upgrade + <see guide>) before proceeding"
task_end

# --- TASK[16]: AXOS daily monitoring checks on OLT ------------------------------------------------------------------------------------------------------------------
task_begin "16" "AXOS daily monitoring checks on OLT"
# FLAG: ssh <olt> "show arp"
# FLAG: ssh <olt> "show ipv6 neighbor"
# FLAG: ssh <olt> "show ont <id> detail"
# FLAG: ssh <olt> "show interface pon bandwidth"
check_tool "ssh" "install openssh client"
require_var "OLT_SSH_TARGET" "export OLT_SSH_TARGET=user@<olt-host>"
require_var "ONT_ID_NUM" "export ONT_ID_NUM=<ont-id> for 'show ont <id> detail'"
note "read-only -- behavior changes after R26.3: show arp / show ipv6 neighbor now hide"
note "delegated-prefix/framed-route entries; show ont <id> detail has a new max-tcont-count field;"
note "'show interface pon bandwidth' now reflects the actual DBA config"
would_run "ssh '${OLT_SSH_TARGET:-user@<olt-host>}' 'show arp'"
would_run "ssh '${OLT_SSH_TARGET:-user@<olt-host>}' 'show ipv6 neighbor'"
would_run "ssh '${OLT_SSH_TARGET:-user@<olt-host>}' 'show ont ${ONT_ID_NUM:-<ont-id>} detail'"
would_run "ssh '${OLT_SSH_TARGET:-user@<olt-host>}' 'show interface pon bandwidth'"
task_end

# --- TASK[17]: EXOS field checks after R26.3 (operator) ----------------------------------------------------------------------------------------------------------------------
task_begin "17" "EXOS field checks after R26.3 (operator)"
note "field workflow from the release notes -- physical checks plus Service Cloud alerts"
operator "verify the box checks in to Calix Service Cloud (TR-069) after the upgrade"
operator "confirm the subscriber-facing apps (CommandIQ/ProtectIQ/SmartBiz) still pair"
operator "review Service Cloud alerts raised by the upgrade before leaving site"
note "nothing scriptable -- Cloud portal + physical presence"
task_end

# --- TASK[18]: AXOS NETCONF notification-drop triage (operator) --------------------------------------------------------------------------------------------------------------------
task_begin "18" "AXOS NETCONF notification-drop triage (operator)"
note "triage workflow from the release notes: NETCONF get no longer returns defaults without with-defaults"
operator "re-run the failing NETCONF get WITH the with-defaults parameter and compare"
operator "check whether the 'missing' data was defaults being omitted (expected) vs a real drop"
operator "only then escalate -- most reports of this are the behavior change, not a bug"
note "nothing scriptable generically -- the rpc payload is site-specific"
task_end

# --- TASK[19]: SmartMDU deployment readiness (operator) --------------------------------------------------------------------------------------------------------------------------------
task_begin "19" "SmartMDU deployment readiness (operator)"
note "checklist/portal workflow from smartmdu.md -- mostly operator steps by design"
operator "walk the SmartMDU deployment checklist in the guide (site survey items first)"
operator "confirm the portal shows the property/building objects before hardware goes in"
operator "verify the MDU-specific provisioning flow in the portal matches the plan"
note "the guide documents no CLI for this flow -- portal + checklist only"
task_end

# --- TASK[00]: NBI logout ---
# FLAG: <action><action-type>logout</action-type></action>
task_begin "00" "NBI logout"
check_tool "curl" "install curl"
require_var CMS_HOST "CMS_HOST=<cms-host> (see task 04)"
default_var CMS_PORT "18080"
default_var NBI_URI "/cms/nbi"
note "closes the server-side session opened in task 04 -- frees one of the 200 client slots"
would_run "curl -s -X POST 'http://${CMS_HOST}:${CMS_PORT}${NBI_URI}' -H 'Content-Type: text/xml; charset=UTF-8' --data @/tmp/nbi-logout.xml"
note 'payload: <rpc message-id="999" nodename="$NODEN" username="$CMS_USER" sessionid="$SESSIONID"> carrying <action><action-type>logout</action-type></action>'
note "expect ResultCode 0; the live run performs this automatically at the end"
task_end

# ----------------------------------------------------------------- report ---

{
    echo "# Dry-run report: CMS (Calix CMS / AXOS / EXOS / SMx / SmartMDU)"
    echo ""
    echo "Generated (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Script: cms/scripts/dry-run.sh (bash)"
    echo ""
    echo "## Summary"
    echo ""
    echo "- Tasks total: $((PASS_COUNT + SKIP_COUNT))"
    echo "- PASS: ${PASS_COUNT}"
    echo "- SKIP: ${SKIP_COUNT}"
    if [ "${SKIP_COUNT}" -gt 0 ]; then
        echo ""
        echo "### Skipped tasks and fix hints"
        echo ""
        for d in "${SKIP_DETAILS[@]}"; do
            echo "- ${d}"
        done
    else
        echo "- No missing prerequisites. Every task is ready to run."
    fi
    echo ""
    echo "## Per-task detail"
    cat "${BODY}"
} > "${REPORT}"
rm -f "${BODY}"

echo ""
echo "================================================================"
echo "CMS dry-run complete: ${PASS_COUNT} PASS, ${SKIP_COUNT} SKIP"
echo "Report: ${REPORT}"
echo "================================================================"
[ "${SKIP_COUNT}" -eq 0 ]
