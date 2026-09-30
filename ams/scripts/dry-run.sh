#!/usr/bin/env bash
#
# dry-run.sh -- verbose dry-run of every documented Nokia 5520 AMS 9.8.3 task.
#
# WHAT IT DOES
#   Walks the 16 operational playbooks from ams/guides/use-cases.md plus the
#   documented flag variants from the other ams/guides/*.md files. For each
#   task it prints the exact command(s) that WOULD run (fully quoted), checks
#   that each required tool exists on PATH, checks that required environment
#   variables are set, and reports a PASS/SKIP verdict.
#
# WHAT IT DOES NOT DO
#   Makes zero changes. No network calls (not even curl probes). Never prints
#   or touches credentials. If anything is missing you get a SKIP with a fix
#   hint, and the exit code is non-zero.
#
# WHERE IT RUNS
#   On the AMS server itself, as the 'amssys' Linux account (sudo is used
#   only where the guides require root). From a laptop instead, use the
#   sibling dry-run.cmd / dry-run.ps1, which reach the server over SSH.
#
# CONFIGURATION (all optional; unset values produce SKIP with a hint)
#   AMS_RELEASE        release path for activation, e.g. /opt/ams/software/9.8.3
#   AMS_SFTP_TARGET    sftp:// URL for the SFTP backup playbook
#   AMS_BACKUP_PATH    local backup archive path (default /backup/prechange-ams.tar.gz)
#   AMS_SFTP_PORT      new SFTP port for the port-change playbook (default 2222)
#   AMS_CLUSTER_IP     cluster IP for the evacuate playbook
#   AMS_MIGRATION_BACKUP  absolute path of the backup used by migrate-from-backup
#   AMS_RESTORE_ARCHIVE   archive path for restore-on-different-hardware
#   AMS_GOLDEN_LABEL   label for 'ams_server version save' (default GOLDEN983)
#   AMS_GOLDEN_PATH    snapshot path for version save/verify
#   AMS_CA_PEM         CA certificate for the NBI HTTPS check
#   AMS_NBI_HOST       host for the NBI HTTPS check
#   NE_LIST / NE_CMD_FILE / NE_OUT / NE_TIMEOUT   inputs for the full ams_ne_cli form
#   NE_MGR_INPUT       input file for ams_ne_mgr
#   NE_BACKUP_TARGET   target archive for ams_nebackup.sh
#   SW_BACKUP_PATH     destination prefix for ams_sw_backup.sh (root)
#
# REPORT
#   Writes reports/dry-run-ams-<UTC>.md next to this script, with a summary
#   section up top, per-task verdicts, the exact commands, and fix hints.
#   The report path is printed at the end of the run.
#
# EXIT CODE
#   0 = every task PASS. 1 = at least one task SKIP (missing prerequisite).

set -uo pipefail

# ---------------------------------------------------------------- helpers ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORT_DIR}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
REPORT="${REPORT_DIR}/dry-run-ams-${STAMP}.md"
BODY="$(mktemp)"

PASS_COUNT=0
SKIP_COUNT=0
declare -a SKIP_DETAILS=()

# log: to console AND the report body. rlog: report body only.
log()  { printf '%s\n' "$*" | tee -a "${BODY}"; }
rlog() { printf '%s\n' "$*" >> "${BODY}"; }

task_begin() { # $1 = id, $2 = name
    CUR_ID="$1"; CUR_NAME="$2"; CUR_SKIP=()
    log ""
    log "### TASK[${CUR_ID}]: ${CUR_NAME}"
}

check_tool() { # $1 = tool name, $2 = fix hint
    local where
    if where="$(command -v "$1" 2>/dev/null)"; then
        log "  [ok] tool present: $1 (${where})"
    else
        CUR_SKIP+=("missing tool '$1' -- $2")
        log "  [MISSING] tool: $1"
        log "            fix: $2"
    fi
}

require_var() { # $1 = var name, $2 = description (value is echoed; never use for secrets)
    local val="${!1:-}"
    if [ -n "${val}" ]; then
        log "  [ok] $1='${val}'"
    else
        CUR_SKIP+=("env var '$1' is not set -- $2")
        log "  [MISSING] env var: $1"
        log "            fix: $2"
    fi
}

require_secret() { # $1 = var name, $2 = description (value NEVER echoed)
    if [ -n "${!1:-}" ]; then
        log "  [ok] $1 is set (value hidden)"
    else
        CUR_SKIP+=("secret '$1' is not set -- $2")
        log "  [MISSING] secret: $1 (value never displayed)"
        log "            fix: $2"
    fi
}

would_run() { log "  would run: $*"; }
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

default_var() { # $1 = var, $2 = default -- assign default only for display of would-run lines
    if [ -z "${!1:-}" ]; then printf -v "$1" '%s' "$2"; fi
}

# ------------------------------------------------------------------ tasks ---

log "# AMS dry-run -- $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "# host: $(hostname 2>/dev/null || echo unknown)  user: $(id -un 2>/dev/null || echo unknown)"

# --- TASK[01]: Activate a release -------------------------------------------
task_begin "01" "Activate a release"
# FLAG: ams_activate.sh <release-path>
# FLAG: ams_server start
# FLAG: ams_server status
# FLAG: ams_server version
check_tool "ams_activate.sh" "run on the AMS server as amssys; activate needs root/sudo"
check_tool "ams_server"      "run on the AMS server as amssys"
require_var "AMS_RELEASE" "export AMS_RELEASE=/opt/ams/software/<release> for your site"
default_var AMS_RELEASE "/opt/ams/software/<release>"
note "impact: service/configuration change -- activation runs as root, server control as amssys"
would_run "sudo '${AMS_RELEASE}/bin/ams_activate.sh'"
would_run "sudo -iu amssys ams_server start"
would_run "sudo -iu amssys ams_server status"
note "variant: confirm the new release with: sudo -iu amssys ams_server version"
would_run "sudo -iu amssys ams_server version"
note "back-out: re-run ams_activate.sh with the previous release path, then start + status"
task_end

# --- TASK[02]: Back up to SFTP ------------------------------------------------
task_begin "02" "Back up to SFTP"
# FLAG: ams_backup.sh -z <sftp-url>
check_tool "ams_backup.sh" "run on the AMS server as amssys"
require_var "AMS_SFTP_TARGET" "export AMS_SFTP_TARGET='sftp://<host>/<path>/ams-backup.tar.gz'"
default_var AMS_SFTP_TARGET "sftp://<host>/<path>/ams-backup.tar.gz"
note "impact: read-only/low impact -- prefer key-based auth for the SFTP target"
would_run "sudo -iu amssys ams_backup.sh -z '${AMS_SFTP_TARGET}'"
note "success looks like: archive exists at the target path and the log confirms a clean run"
task_end

# --- TASK[03]: Change SFTP port -----------------------------------------------
task_begin "03" "Change SFTP port"
# FLAG: ams_set_sftp_port.sh --check
# FLAG: ams_set_sftp_port.sh <port>
# FLAG: ams_server restart
# FLAG: ams_updatefirewall
check_tool "ams_set_sftp_port.sh" "run on the AMS server (privileged)"
check_tool "ams_server"           "run on the AMS server as amssys"
check_tool "ams_updatefirewall"   "run on the AMS server as root"
require_var "AMS_SFTP_PORT" "export AMS_SFTP_PORT=<new-port> for your site"
default_var AMS_SFTP_PORT "2222"
note "impact: service/configuration change -- SFTP restarts on the new port"
would_run "ams_set_sftp_port.sh --check"
note "variant: set the port (example ${AMS_SFTP_PORT}):"
would_run "ams_set_sftp_port.sh '${AMS_SFTP_PORT}'"
would_run "ams_server restart"
would_run "ams_updatefirewall"
note "back-out: re-run ams_set_sftp_port.sh with the previous port, then restart + ams_updatefirewall"
task_end

# --- TASK[04]: Collect a support bundle -----------------------------------------
task_begin "04" "Collect a support bundle"
# FLAG: ams_cluster status --detailed
# FLAG: ams_log_manager.sh --collect --category all --target all --destination <uri>
# FLAG: ams_support.sh --domain app --command jstack --target all --destination <path>
# FLAG: ams_support.sh --domain app --command jmap --target all --destination <path>
check_tool "ams_cluster"       "run on the AMS server as amssys"
check_tool "ams_log_manager.sh" "run on the AMS server as amssys"
check_tool "ams_support.sh"    "run on the AMS server as amssys"
note "impact: bundle may contain sensitive data; jstack/jmap add JVM load -- warn the NOC first"
would_run "ams_cluster status --detailed"
would_run "ams_log_manager.sh --collect --category all --target all --destination 'file:///tmp/ams-support.tar'"
would_run "ams_support.sh --domain app --command jstack --target all --destination '/tmp/ams-jstack.tar'"
note "variant: heap dump instead of (or after) threads -- take jstack BEFORE the heavier jmap:"
would_run "ams_support.sh --domain app --command jmap --target all --destination '/tmp/ams-jmap.tar'"
note "success looks like: both .tar files exist with non-trivial size; ship over a secure channel only"
task_end

# --- TASK[05]: Convert simplex to cluster ----------------------------------------
task_begin "05" "Convert simplex to cluster"
# FLAG: ams_server stop
# FLAG: ams_simplex_to_cluster.sh   (interactive)
# FLAG: ams_updatefirewall
# FLAG: ams_server start
# FLAG: ams_cluster status --detailed
check_tool "ams_server"               "run on the AMS server as amssys"
check_tool "ams_simplex_to_cluster.sh" "run on the AMS server as amssys (interactive)"
check_tool "ams_updatefirewall"       "run on the AMS server as root"
check_tool "ams_cluster"              "run on the AMS server as amssys"
note "impact: SERVICE-AFFECTING -- ams_simplex_to_cluster.sh is interactive:"
note "  have the cluster NIC, multicast addresses, and alternate data-server details on paper first"
would_run "ams_server stop"
would_run "ams_simplex_to_cluster.sh   # interactive -- answer its prompts"
would_run "ams_updatefirewall"
would_run "ams_server start"
would_run "ams_cluster status --detailed"
note "back-out: no automated de-conversion -- restore from the tested pre-change backup"
task_end

# --- TASK[06]: Defragment database -----------------------------------------------
task_begin "06" "Defragment database"
# FLAG: ams_db_defragment.sh all analyse
# FLAG: ams_db_defragment.sh all execute
# FLAG: ams_server stop
# FLAG: ams_server start
check_tool "ams_server" "run on the AMS server as amssys"
note "tool path: \$AMSSCRIPTSDIR/ams_db_defragment.sh (AMSSCRIPTSDIR is on the amssys PATH context)"
if [ -n "${AMSSCRIPTSDIR:-}" ]; then
    log "  [ok] AMSSCRIPTSDIR='${AMSSCRIPTSDIR}'"
    check_tool "${AMSSCRIPTSDIR}/ams_db_defragment.sh" "expected via \$AMSSCRIPTSDIR on the AMS server"
else
    CUR_SKIP+=("env var 'AMSSCRIPTSDIR' is not set -- present on the AMS server for amssys; export it or run there")
    log "  [MISSING] env var: AMSSCRIPTSDIR"
fi
note "impact: run ANALYSE any time; run EXECUTE only on the active data server in a maintenance window"
would_run "\${AMSSCRIPTSDIR}/ams_db_defragment.sh all analyse"
would_run "ams_server stop"
would_run "\${AMSSCRIPTSDIR}/ams_db_defragment.sh all execute"
would_run "ams_server start"
note "back-out: none -- defragmentation has no undo; restore from backup if execute causes problems"
task_end

# --- TASK[07]: Evacuate application server ------------------------------------------
task_begin "07" "Evacuate application server"
# FLAG: ams_cluster status --detailed
# FLAG: ams_cluster evacuate_ne <cluster-ip>
# FLAG: ams_show_ne_balancing.sh -a <cluster-ip>
# FLAG: ams_server stop maintenance
# FLAG: ams_server start
# FLAG: ams_cluster unevacuate_ne <cluster-ip> <weight>
check_tool "ams_cluster"             "run on the AMS server as amssys"
check_tool "ams_show_ne_balancing.sh" "run on the AMS server as amssys"
check_tool "ams_server"              "run on the AMS server as amssys"
require_var "AMS_CLUSTER_IP" "export AMS_CLUSTER_IP=<cluster-ip> of the host to evacuate"
default_var AMS_CLUSTER_IP "<cluster-ip>"
note "impact: capacity/placement -- record placement and confirm remaining capacity BEFORE evacuating"
would_run "ams_cluster status --detailed"
would_run "ams_cluster evacuate_ne '${AMS_CLUSTER_IP}'"
would_run "ams_show_ne_balancing.sh -a '${AMS_CLUSTER_IP}'"
would_run "ams_server stop maintenance"
note "return-to-service sequence:"
would_run "ams_server start"
would_run "ams_cluster unevacuate_ne '${AMS_CLUSTER_IP}' 1"
would_run "ams_cluster status --detailed"
note "back-out: start, then unevacuate_ne with the RECORDED weight (rebalancing is not guaranteed identical)"
task_end

# --- TASK[08]: Fall back to local authentication --------------------------------------
task_begin "08" "Fall back to local authentication"
# FLAG: ams_switch_authentication_local
check_tool "ams_switch_authentication_local" "run on the AMS server as amssys"
note "impact: security change -- use when LDAP/RADIUS failure blocks logins"
would_run "ams_switch_authentication_local"
note "back-out: restore the external auth afterwards per site procedure; record which config was active"
task_end

# --- TASK[09]: Force data-server switchover --------------------------------------------
task_begin "09" "Force data-server switchover"
# FLAG: ams_cluster status --detailed
# FLAG: ams_switch_active_dataserver
# FLAG: ams_switch_active_dataserver -f   (automation only, with independent health checks)
check_tool "ams_cluster"                "run on the AMS server as amssys"
check_tool "ams_switch_active_dataserver" "run on the AMS server as amssys"
note "impact: service-affecting -- the -f flag is for automation with independent health checks ONLY"
would_run "ams_cluster status --detailed"
would_run "ams_switch_active_dataserver"
note "variant (NOT for interactive use): ams_switch_active_dataserver -f"
would_run "ams_cluster status --detailed"
note "back-out: run ams_switch_active_dataserver again to switch back, verify with status --detailed"
task_end

# --- TASK[10]: Migrate from backup -------------------------------------------------------
task_begin "10" "Migrate from backup"
# FLAG: ams_cluster stop
# FLAG: ams_copy_datafiles --force --from-backup <path>
# FLAG: ams_server start
# FLAG: ams_server status all -l 30 -p 60
check_tool "ams_cluster"        "run on the AMS server as amssys"
check_tool "ams_copy_datafiles" "run on the AMS server (privileged)"
check_tool "ams_server"         "run on the AMS server as amssys"
require_var "AMS_MIGRATION_BACKUP" "export AMS_MIGRATION_BACKUP=/absolute/path/source-backup.tar"
default_var AMS_MIGRATION_BACKUP "/absolute/path/source-backup.tar"
note "impact: HIGH and service-affecting -- install required plug-ins BEFORE the persistency copy"
would_run "ams_cluster stop"
would_run "ams_copy_datafiles --force --from-backup '${AMS_MIGRATION_BACKUP}'"
would_run "ams_server start"
would_run "ams_server status all -l 30 -p 60"
note "back-out: restore from the tested pre-change backup; this playbook overwrites data in place"
task_end

# --- TASK[11]: Recover administrator -------------------------------------------------------
task_begin "11" "Recover administrator"
# FLAG: ams_support.sh --domain security --command killadminsessions
# FLAG: ams_support.sh --domain security --command resetadminpwd
check_tool "ams_support.sh" "run on the AMS server as amssys"
note "impact: security-sensitive -- check release/setup restrictions first"
would_run "ams_support.sh --domain security --command killadminsessions"
would_run "ams_support.sh --domain security --command resetadminpwd"
note "afterwards: re-secure the account immediately (proper password, verify sessions)"
task_end

# --- TASK[12]: Restore on different hardware -----------------------------------------------
task_begin "12" "Restore on different hardware"
# FLAG: ams_restore.sh -n <archive>
# FLAG: ams_install_license   (root/sudo)
# FLAG: ams_server start
check_tool "ams_restore.sh"    "run on the AMS server as amssys"
check_tool "ams_install_license" "license install needs root/sudo"
check_tool "ams_server"         "run on the AMS server as amssys"
require_var "AMS_RESTORE_ARCHIVE" "export AMS_RESTORE_ARCHIVE=/backup/ams-data.tar"
default_var AMS_RESTORE_ARCHIVE "/backup/ams-data.tar"
note "impact: HIGH and service-affecting -- old licenses do not apply; install new-host licenses"
would_run "ams_restore.sh -n '${AMS_RESTORE_ARCHIVE}'"
would_run "sudo ams_install_license"
would_run "ams_server start"
note "back-out: restore from the pre-change backup of the target host"
task_end

# --- TASK[13]: Rotate database credentials ---------------------------------------------------
task_begin "13" "Rotate database credentials"
# FLAG: ams_update_database_pwd.sh
check_tool "ams_update_database_pwd.sh" "run as amssys or root"
note "impact: HIGH -- the script stops AMS, updates credentials, and AUTO-STARTS the cluster afterwards"
note "rule: new password <= 32 chars, no spaces. Do NOT manually restart afterwards."
would_run "ams_update_database_pwd.sh"
note "back-out: not reversible in place -- restore from the tested pre-change backup"
task_end

# --- TASK[14]: Take a pre-change backup -------------------------------------------------------
task_begin "14" "Take a pre-change backup"
# FLAG: ams_cluster status --detailed
# FLAG: ams_server version
# FLAG: ams_backup.sh -z <path>
check_tool "ams_cluster"   "run on the AMS server as amssys"
check_tool "ams_server"    "run on the AMS server as amssys"
check_tool "ams_backup.sh" "run on the AMS server as amssys"
require_var "AMS_BACKUP_PATH" "export AMS_BACKUP_PATH=/backup/prechange-ams.tar.gz"
default_var AMS_BACKUP_PATH "/backup/prechange-ams.tar.gz"
note "impact: read-only/low impact -- run before EVERY non-trivial change"
would_run "ams_cluster status --detailed"
would_run "ams_server version"
would_run "ams_backup.sh -z '${AMS_BACKUP_PATH}'"
note "success looks like: archive exists at the path and the log confirms a clean run"
task_end

# --- TASK[15]: Validate installed software -----------------------------------------------------
task_begin "15" "Validate installed software"
# FLAG: ams_server version save --label <label> <path>
# FLAG: ams_server version verify <path>
# FLAG: ams_cluster status sw
check_tool "ams_server"  "run on the AMS server as amssys"
check_tool "ams_cluster" "run on the AMS server as amssys"
require_var "AMS_GOLDEN_LABEL" "export AMS_GOLDEN_LABEL=GOLDEN983 (snapshot label)"
require_var "AMS_GOLDEN_PATH"  "export AMS_GOLDEN_PATH=/secure/GoldenEMSSwConfig (snapshot path)"
default_var AMS_GOLDEN_LABEL "GOLDEN983"
default_var AMS_GOLDEN_PATH "/secure/GoldenEMSSwConfig"
note "impact: read-only -- save the golden snapshot once from a known-good system"
would_run "ams_server version save --label '${AMS_GOLDEN_LABEL}' '${AMS_GOLDEN_PATH}'"
would_run "ams_server version verify '${AMS_GOLDEN_PATH}'"
would_run "ams_cluster status sw"
note "success looks like: verify reports no differences; status sw shows agreement on all nodes"
task_end

# --- TASK[16]: Verify NBI over HTTPS ---------------------------------------------------------------
task_begin "16" "Verify NBI over HTTPS"
# FLAG: curl --cacert <pem> https://<host>:8443/ams/services/UserManagementMgr
# FLAG: curl --cacert <pem> https://<host>:8443/ams/schema/doc/html/index.html
check_tool "curl" "install curl (any platform)"
require_var "AMS_CA_PEM"   "export AMS_CA_PEM=/path/ams-ca.pem (site CA certificate)"
require_var "AMS_NBI_HOST" "export AMS_NBI_HOST=<host> (AMS northbound host)"
default_var AMS_CA_PEM "/path/ams-ca.pem"
default_var AMS_NBI_HOST "<host>"
note "impact: read-only -- proves the NBI answers over TLS before debugging any SOAP integration"
would_run "curl --cacert '${AMS_CA_PEM}' 'https://${AMS_NBI_HOST}:8443/ams/services/UserManagementMgr'"
would_run "curl --cacert '${AMS_CA_PEM}' 'https://${AMS_NBI_HOST}:8443/ams/schema/doc/html/index.html'"
note "success looks like: both endpoints answer (service descriptor + schema docs page load)"
task_end

# --- TASK[17]: NE CLI transport probes ----------------------------------------------------------------
task_begin "17" "NE CLI transport probes"
# FLAG: ams_ne_cli -protocol
# FLAG: ams_ne_cli -buffer
# FLAG: ams_ne_cli <ne-list> <command-file> <output-file> <timeout>
check_tool "ams_ne_cli" "run on the AMS server as amssys"
note "impact: probes are read-only; the full 4-arg form EXECUTES NE-native commands verbatim (review twice)"
would_run "ams_ne_cli -protocol"
would_run "ams_ne_cli -buffer"
require_var "NE_LIST"     "export NE_LIST=/tmp/ne-list.txt (needed for the full form)"
require_var "NE_CMD_FILE" "export NE_CMD_FILE=/tmp/commands.txt (needed for the full form)"
require_var "NE_OUT"      "export NE_OUT=/tmp/ne_cli_out.txt (needed for the full form)"
require_var "NE_TIMEOUT"  "export NE_TIMEOUT=120 (seconds; needed for the full form)"
default_var NE_LIST "/tmp/ne-list.txt"
default_var NE_CMD_FILE "/tmp/commands.txt"
default_var NE_OUT "/tmp/ne_cli_out.txt"
default_var NE_TIMEOUT "120"
note "variant: full run against a target list (validate every line against the NE family command reference):"
would_run "ams_ne_cli '${NE_LIST}' '${NE_CMD_FILE}' '${NE_OUT}' '${NE_TIMEOUT}'"
task_end

# --- TASK[18]: NE manager help and flags ------------------------------------------------------------------
task_begin "18" "NE manager help and flags"
# FLAG: ams_ne_mgr --help
# FLAG: ams_ne_mgr [options] <input-file>
check_tool "ams_ne_mgr" "run on the AMS server as amssys"
note "impact: --help is read-only; the real run is provisioning (mass create/modify from a file)"
would_run "ams_ne_mgr --help"
note "gotcha from the guide: an IP-address change CANNOT be combined with other attribute changes -- split passes"
require_var "NE_MGR_INPUT" "export NE_MGR_INPUT=<input-file> to preview the real invocation"
default_var NE_MGR_INPUT "<input-file>"
would_run "ams_ne_mgr '${NE_MGR_INPUT}'"
task_end

# --- TASK[19]: Back up NE data ------------------------------------------------------------------------------
task_begin "19" "Back up NE data"
# FLAG: ams_nebackup.sh <target>
check_tool "ams_nebackup.sh" "run on the AMS server as amssys"
require_var "NE_BACKUP_TARGET" "export NE_BACKUP_TARGET=/backup/ne-prechange.tar"
default_var NE_BACKUP_TARGET "/backup/ne-prechange.tar"
note "impact: writes a backup file (no live data changed)"
would_run "ams_nebackup.sh '${NE_BACKUP_TARGET}'"
task_end

# --- TASK[20]: Schedule backups (interactive) -------------------------------------------------------------------
task_begin "20" "Schedule backups (interactive)"
# FLAG: ams_schedule_backup -int
# FLAG: ams_schedule_backup
check_tool "ams_schedule_backup" "run on the AMS server as amssys"
note "impact: scheduling change -- '-int' is INTERACTIVE (answers questions, builds the schedule)"
would_run "ams_schedule_backup -int   # interactive: answer its prompts"
would_run "ams_schedule_backup        # applies/activates the schedule"
note "gotcha: if the OS time zone ever changes, restart crond afterwards or the schedule silently shifts"
task_end

# --- TASK[21]: Back up AMS software --------------------------------------------------------------------------------
task_begin "21" "Back up AMS software"
# FLAG: ams_sw_backup.sh <path>   (root)
check_tool "ams_sw_backup.sh" "run as root -- sudo is used"
require_var "SW_BACKUP_PATH" "export SW_BACKUP_PATH=/backup/ams-software"
default_var SW_BACKUP_PATH "/backup/ams-software"
note "impact: I/O intensive -- the script appends <hostname>.bin to the path you give it"
would_run "sudo ams_sw_backup.sh '${SW_BACKUP_PATH}'"
task_end

# --- TASK[22]: Check SSL/JBoss state -------------------------------------------------------------------------------
task_begin "22" "Check SSL/JBoss state"
# FLAG: ams_check_ssl.sh
check_tool "ams_check_ssl.sh" "run on the AMS server as amssys"
note "impact: read-only"
would_run "ams_check_ssl.sh"
task_end

# --- TASK[23]: Reset AMS logs ------------------------------------------------------------------------------------------
task_begin "23" "Reset AMS logs"
# FLAG: ams_reset_logs.sh
check_tool "ams_reset_logs.sh" "run on the AMS server as amssys"
note "impact: DESTRUCTIVE TO LOGS -- never reset before collecting the evidence you need"
would_run "ams_reset_logs.sh"
task_end

# --- TASK[24]: Geo redundancy commands -------------------------------------------------------------------------------------
task_begin "24" "Geo redundancy commands"
# FLAG: ams_cluster start -force active
# FLAG: ams_cluster start -force standby
# FLAG: ams_cluster switch active
# FLAG: ams_cluster switch standby
# FLAG: ams_cluster switch active -force
# FLAG: ams_server resetgeo
check_tool "ams_cluster" "run on the AMS server as amssys"
check_tool "ams_server"  "run on the AMS server as amssys"
note "impact: service-affecting -- -force bypasses role checks; verify the remote site first (dual-active risk)"
note "variant: start this site in a forced geo role:"
would_run "ams_cluster start -force active"
would_run "ams_cluster start -force standby"
note "variant: switch geo roles (plain, then forced):"
would_run "ams_cluster switch active"
would_run "ams_cluster switch standby"
would_run "ams_cluster switch active -force"
note "variant: clear the geo monitor timer -- ONLY after remediation:"
would_run "ams_server resetgeo"
task_end

# ----------------------------------------------------------------- report ---

{
    echo "# Dry-run report: AMS (Nokia 5520 AMS 9.8.3)"
    echo ""
    echo "Generated (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Script: ams/scripts/dry-run.sh (bash, runs on the AMS server as amssys)"
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
echo "AMS dry-run complete: ${PASS_COUNT} PASS, ${SKIP_COUNT} SKIP"
echo "Report: ${REPORT}"
echo "================================================================"
[ "${SKIP_COUNT}" -eq 0 ]
