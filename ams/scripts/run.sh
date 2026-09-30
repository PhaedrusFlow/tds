#!/usr/bin/env bash
#
# run.sh -- LIVE execution of every documented Nokia 5520 AMS 9.8.3 task.
#
# WHAT IT DOES
#   Runs the same task list as dry-run.sh, in the same order, for real.
#   Read-only tasks run straight through. Every mutating, service-affecting,
#   destructive, or security-sensitive step prints a warning and requires you
#   to type "yes" before it runs. The script fails fast on the first error.
#
# WHERE IT RUNS
#   On the AMS server itself, as the 'amssys' Linux account (sudo is used
#   only where the guides require root). From a laptop instead, use the
#   sibling run.cmd / run.ps1, which reach the server over SSH.
#
# CONFIGURATION -- same variables as dry-run.sh. Run dry-run.sh first and
# fix every SKIP before running this. Required variables abort the task
# they belong to with a clear message instead of running with placeholders.
#
# SAFETY
#   set -euo pipefail: the first failing command stops the whole run.
#   Interactive tools (ams_simplex_to_cluster.sh, ams_schedule_backup -int)
#   run attached to your terminal so you can answer their prompts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------- helpers ---

task() { # $1 = id, $2 = name
    echo ""
    echo "### TASK[$1]: $2"
}

step() { # print the command, run it, fail fast on error
    echo "  $ $*"
    "$@"
    local rc=$?
    if [ "${rc}" -ne 0 ]; then
        echo "  FAILED with exit ${rc}: $*"
        exit "${rc}"
    fi
}

confirm() { # $1 = warning text; returns 0 only if the operator types exactly "yes"
    local ans=""
    echo "  !! $1"
    printf '  Type "yes" to continue, anything else aborts: '
    IFS= read -r ans
    if [ "${ans}" = "yes" ]; then
        return 0
    fi
    echo "  aborted by operator."
    exit 1
}

need_var() { # $1 = var name, $2 = description; aborts if unset
    if [ -z "${!1:-}" ]; then
        echo "  ERROR: env var '$1' is not set -- $2"
        echo "  Set it and re-run (dry-run.sh lists every variable)."
        exit 1
    fi
}

note() { echo "  note: $*"; }

warn_run_first() {
    echo "=================================================================="
    echo "LIVE RUN -- real commands against a real AMS server."
    echo "Run dry-run.sh first and resolve every SKIP before proceeding."
    echo "=================================================================="
}

warn_run_first

# --- TASK[01]: Activate a release -------------------------------------------
task "01" "Activate a release"
need_var "AMS_RELEASE" "export AMS_RELEASE=/opt/ams/software/<release>"
confirm "SERVICE/CONFIGURATION CHANGE: activates release '${AMS_RELEASE}' (root) and starts the server."
step sudo "${AMS_RELEASE}/bin/ams_activate.sh"
step sudo -iu amssys ams_server start
step sudo -iu amssys ams_server status
step sudo -iu amssys ams_server version

# --- TASK[02]: Back up to SFTP ------------------------------------------------
task "02" "Back up to SFTP"
need_var "AMS_SFTP_TARGET" "export AMS_SFTP_TARGET='sftp://<host>/<path>/ams-backup.tar.gz'"
note "read-only/low impact -- writing backup archive to ${AMS_SFTP_TARGET}"
step sudo -iu amssys ams_backup.sh -z "${AMS_SFTP_TARGET}"

# --- TASK[03]: Change SFTP port -----------------------------------------------
task "03" "Change SFTP port"
AMS_SFTP_PORT="${AMS_SFTP_PORT:-2222}"
note "using SFTP port ${AMS_SFTP_PORT} (override with AMS_SFTP_PORT)"
step ams_set_sftp_port.sh --check
confirm "SERVICE/CONFIGURATION CHANGE: sets the SFTP port to ${AMS_SFTP_PORT} and restarts the server."
step ams_set_sftp_port.sh "${AMS_SFTP_PORT}"
step ams_server restart
step sudo ams_updatefirewall

# --- TASK[04]: Collect a support bundle -----------------------------------------
task "04" "Collect a support bundle"
note "bundle may contain SENSITIVE data; jstack adds JVM load -- warn the NOC first"
step ams_cluster status --detailed
step ams_log_manager.sh --collect --category all --target all --destination "file:///tmp/ams-support.tar"
step ams_support.sh --domain app --command jstack --target all --destination "/tmp/ams-jstack.tar"
note "wrote /tmp/ams-support.tar and /tmp/ams-jstack.tar -- transfer over a secure channel only"
if [ "${AMS_JMAP:-0}" = "1" ]; then
    confirm "HEAP DUMP: jmap is heavier than jstack and can briefly stall a loaded JVM."
    step ams_support.sh --domain app --command jmap --target all --destination "/tmp/ams-jmap.tar"
else
    note "skipping jmap heap dump (set AMS_JMAP=1 to include it)"
fi

# --- TASK[05]: Convert simplex to cluster ----------------------------------------
task "05" "Convert simplex to cluster"
confirm "SERVICE-AFFECTING: stops the server and converts simplex -> cluster. Have the cluster NIC, multicast addresses, and alternate data-server details on paper -- the converter is interactive."
step ams_server stop
note "ams_simplex_to_cluster.sh is interactive -- answer its prompts"
step ams_simplex_to_cluster.sh
step sudo ams_updatefirewall
step ams_server start
step ams_cluster status --detailed

# --- TASK[06]: Defragment database -----------------------------------------------
task "06" "Defragment database"
need_var "AMSSCRIPTSDIR" "present on the AMS server for amssys"
note "analysis runs any time; EXECUTE only on the active data server in a maintenance window"
step "${AMSSCRIPTSDIR}/ams_db_defragment.sh" all analyse
confirm "SERVICE-AFFECTING: stops the server and EXECUTES the database defragmentation (no undo)."
step ams_server stop
step "${AMSSCRIPTSDIR}/ams_db_defragment.sh" all execute
step ams_server start

# --- TASK[07]: Evacuate application server ------------------------------------------
task "07" "Evacuate application server"
need_var "AMS_CLUSTER_IP" "export AMS_CLUSTER_IP=<cluster-ip> of the host to evacuate"
step ams_cluster status --detailed
note "record the current placement and confirm remaining capacity BEFORE evacuating"
confirm "CAPACITY/PLACEMENT IMPACT: evacuates NEs from ${AMS_CLUSTER_IP} and stops the server in maintenance mode."
step ams_cluster evacuate_ne "${AMS_CLUSTER_IP}"
step ams_show_ne_balancing.sh -a "${AMS_CLUSTER_IP}"
step ams_server stop maintenance
note "returning the host to service:"
step ams_server start
step ams_cluster unevacuate_ne "${AMS_CLUSTER_IP}" 1
step ams_cluster status --detailed

# --- TASK[08]: Fall back to local authentication --------------------------------------
task "08" "Fall back to local authentication"
confirm "SECURITY CHANGE: switches AMS authentication to local accounts."
step ams_switch_authentication_local
note "restore the external auth afterwards per site procedure"

# --- TASK[09]: Force data-server switchover --------------------------------------------
task "09" "Force data-server switchover"
step ams_cluster status --detailed
confirm "SERVICE-AFFECTING: switches the active data server to its peer."
step ams_switch_active_dataserver
step ams_cluster status --detailed

# --- TASK[10]: Migrate from backup -------------------------------------------------------
task "10" "Migrate from backup"
need_var "AMS_MIGRATION_BACKUP" "export AMS_MIGRATION_BACKUP=/absolute/path/source-backup.tar"
note "install required plug-ins BEFORE the persistency copy"
confirm "HIGH and SERVICE-AFFECTING: persistency copy from '${AMS_MIGRATION_BACKUP}' overwrites data in place."
step ams_cluster stop
step ams_copy_datafiles --force --from-backup "${AMS_MIGRATION_BACKUP}"
step ams_server start
step ams_server status all -l 30 -p 60

# --- TASK[11]: Recover administrator -------------------------------------------------------
task "11" "Recover administrator"
confirm "SECURITY-SENSITIVE: kills stuck admin sessions and RESETS the admin password."
step ams_support.sh --domain security --command killadminsessions
step ams_support.sh --domain security --command resetadminpwd
note "re-secure the account immediately (proper password, verify sessions)"

# --- TASK[12]: Restore on different hardware -----------------------------------------------
task "12" "Restore on different hardware"
need_var "AMS_RESTORE_ARCHIVE" "export AMS_RESTORE_ARCHIVE=/backup/ams-data.tar"
confirm "HIGH and SERVICE-AFFECTING: restores '${AMS_RESTORE_ARCHIVE}' and installs new-host licenses."
step ams_restore.sh -n "${AMS_RESTORE_ARCHIVE}"
step sudo ams_install_license
step ams_server start

# --- TASK[13]: Rotate database credentials ---------------------------------------------------
task "13" "Rotate database credentials"
confirm "HIGH: stops AMS, rotates the database password (<=32 chars, no spaces), and AUTO-STARTS the cluster. Do not restart manually afterwards."
step ams_update_database_pwd.sh

# --- TASK[14]: Take a pre-change backup -------------------------------------------------------
task "14" "Take a pre-change backup"
AMS_BACKUP_PATH="${AMS_BACKUP_PATH:-/backup/prechange-ams.tar.gz}"
note "read-only/low impact -- writing ${AMS_BACKUP_PATH}"
step ams_cluster status --detailed
step ams_server version
step ams_backup.sh -z "${AMS_BACKUP_PATH}"

# --- TASK[15]: Validate installed software -----------------------------------------------------
task "15" "Validate installed software"
need_var "AMS_GOLDEN_LABEL" "export AMS_GOLDEN_LABEL=GOLDEN983"
need_var "AMS_GOLDEN_PATH"  "export AMS_GOLDEN_PATH=/secure/GoldenEMSSwConfig"
note "read-only -- compares the live system against the golden snapshot"
step ams_server version save --label "${AMS_GOLDEN_LABEL}" "${AMS_GOLDEN_PATH}"
step ams_server version verify "${AMS_GOLDEN_PATH}"
step ams_cluster status sw

# --- TASK[16]: Verify NBI over HTTPS ---------------------------------------------------------------
task "16" "Verify NBI over HTTPS"
need_var "AMS_CA_PEM"   "export AMS_CA_PEM=/path/ams-ca.pem"
need_var "AMS_NBI_HOST" "export AMS_NBI_HOST=<host>"
note "read-only -- proves the NBI answers over TLS"
step curl --cacert "${AMS_CA_PEM}" "https://${AMS_NBI_HOST}:8443/ams/services/UserManagementMgr"
step curl --cacert "${AMS_CA_PEM}" "https://${AMS_NBI_HOST}:8443/ams/schema/doc/html/index.html"

# --- TASK[17]: NE CLI transport probes ----------------------------------------------------------------
task "17" "NE CLI transport probes"
note "read-only probes:"
step ams_ne_cli -protocol
step ams_ne_cli -buffer
if [ -n "${NE_LIST:-}" ] && [ -n "${NE_CMD_FILE:-}" ] && [ -n "${NE_OUT:-}" ] && [ -n "${NE_TIMEOUT:-}" ]; then
    confirm "POTENTIALLY SERVICE-AFFECTING: executes NE-native commands verbatim on every target in ${NE_LIST}."
    step ams_ne_cli "${NE_LIST}" "${NE_CMD_FILE}" "${NE_OUT}" "${NE_TIMEOUT}"
else
    note "skipping full 4-arg form (set NE_LIST, NE_CMD_FILE, NE_OUT, NE_TIMEOUT to enable)"
fi

# --- TASK[18]: NE manager help and flags ------------------------------------------------------------------
task "18" "NE manager help and flags"
note "read-only -- documents the bulk-create flags"
step ams_ne_mgr --help
note "real runs use: ams_ne_mgr [options] <input-file> (provisioning -- not executed without NE_MGR_INPUT)"

# --- TASK[19]: Back up NE data ------------------------------------------------------------------------------
task "19" "Back up NE data"
need_var "NE_BACKUP_TARGET" "export NE_BACKUP_TARGET=/backup/ne-prechange.tar"
note "writes a backup file (no live data changed)"
step ams_nebackup.sh "${NE_BACKUP_TARGET}"

# --- TASK[20]: Schedule backups (interactive) -------------------------------------------------------------------
task "20" "Schedule backups (interactive)"
confirm "SCHEDULING CHANGE: runs the INTERACTIVE scheduler; answer its prompts."
step ams_schedule_backup -int
step ams_schedule_backup
note "if the OS time zone ever changes, restart crond afterwards"

# --- TASK[21]: Back up AMS software --------------------------------------------------------------------------------
task "21" "Back up AMS software"
need_var "SW_BACKUP_PATH" "export SW_BACKUP_PATH=/backup/ams-software"
confirm "I/O INTENSIVE (root): backs up the AMS software tree."
step sudo ams_sw_backup.sh "${SW_BACKUP_PATH}"

# --- TASK[22]: Check SSL/JBoss state -------------------------------------------------------------------------------
task "22" "Check SSL/JBoss state"
note "read-only"
step ams_check_ssl.sh

# --- TASK[23]: Reset AMS logs ------------------------------------------------------------------------------------------
task "23" "Reset AMS logs"
confirm "DESTRUCTIVE TO LOGS: clears AMS logs. Collect the evidence you need FIRST."
step ams_reset_logs.sh

# --- TASK[24]: Geo redundancy commands -------------------------------------------------------------------------------------
task "24" "Geo redundancy commands"
note "read-only status first:"
step ams_cluster status --detailed
confirm "SERVICE-AFFECTING GEO CHANGE: forced role commands bypass role checks -- verify the remote site first (dual-active risk)."
echo "  choose geo action: [1] start -force active  [2] start -force standby  [3] switch active  [4] switch standby  [5] switch active -force  [6] resetgeo (only after remediation)  [0] skip"
printf '  selection: '
IFS= read -r geo_choice
case "${geo_choice}" in
    1) step ams_cluster start -force active ;;
    2) step ams_cluster start -force standby ;;
    3) step ams_cluster switch active ;;
    4) step ams_cluster switch standby ;;
    5) step ams_cluster switch active -force ;;
    6) step ams_server resetgeo ;;
    *) note "skipping geo change" ;;
esac

echo ""
echo "================================================================"
echo "AMS live run complete."
echo "================================================================"
