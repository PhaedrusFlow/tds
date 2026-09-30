@echo off
REM ============================================================================
REM dry-run.cmd -- verbose dry-run of every documented Nokia 5520 AMS 9.8.3 task
REM
REM Walks the 16 operational playbooks from ams/guides/use-cases.md plus the
REM documented flag variants from the other ams/guides/*.md files. For each
REM task it prints the exact command(s) that WOULD run (fully quoted), checks
REM prerequisites, and reports a PASS/SKIP verdict. Makes zero changes: no
REM network calls beyond read-only SSH 'command -v' probes, no mutations,
REM never prints or touches credentials.
REM
REM AMS commands run on the RHEL server as amssys; this script reaches it over
REM SSH from Windows. Set AMS_HOST, e.g.  set "AMS_HOST=amssys@ams-prod-01"
REM
REM REPORT: writes reports\dry-run-ams-<UTC>.md next to this script: summary
REM up top, per-task verdicts, exact commands, and fix hints. The path is
REM printed at the end. Exit 0 = all PASS, exit 1 = at least one SKIP.
REM ============================================================================
setlocal EnableDelayedExpansion

if "%AMS_HOST%"=="" (
    echo ERROR: set AMS_HOST first, e.g.  set "AMS_HOST=amssys@ams-prod-01"
    exit /b 1
)
set "REMOTE=%AMS_HOST%"
where ssh >nul 2>&1
if errorlevel 1 (
    echo ERROR: ssh not found. Install Win32 OpenSSH ^(Settings ^> Apps ^> Optional features^).
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "REPORT_DIR=%SCRIPT_DIR%reports"
if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%" >nul
for /f %%t in ('powershell -NoProfile -Command "(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')"') do set "STAMP=%%t"
for /f %%t in ('powershell -NoProfile -Command "(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')"') do set "NOWUTC=%%t"
set "REPORT=%REPORT_DIR%dry-run-ams-%STAMP%.md"
set "BODY=%REPORT_DIR%.dry-run-body.tmp"
set "SKIPFILE=%REPORT_DIR%.dry-run-skips.tmp"
if exist "%BODY%" del "%BODY%"
if exist "%SKIPFILE%" del "%SKIPFILE%"
set /a PASS_COUNT=0
set /a SKIP_COUNT=0

call :log "# AMS dry-run -- %NOWUTC%"
call :log "# via SSH to: %REMOTE% (cmd.exe)"

REM ============================ TASK[01] =====================================
REM FLAG: ams_activate.sh <release-path>
REM FLAG: ams_server start
REM FLAG: ams_server status
REM FLAG: ams_server version
call :task_begin "01" "Activate a release"
call :check_tool_remote "ams_activate.sh" "activation runs on the AMS server; needs root/sudo there"
call :check_tool_remote "ams_server" "runs on the AMS server as amssys"
call :require_var "AMS_RELEASE" "set AMS_RELEASE=/opt/ams/software/<release> for your site"
call :get_or "AMS_RELEASE" "/opt/ams/software/<release>"
call :note "impact: service/configuration change -- activation runs as root, server control as amssys"
call :show_run "sudo '!AMS_RELEASE!/bin/ams_activate.sh'"
call :show_run "sudo -iu amssys ams_server start"
call :show_run "sudo -iu amssys ams_server status"
call :note "variant: confirm the new release with: sudo -iu amssys ams_server version"
call :show_run "sudo -iu amssys ams_server version"
call :note "back-out: re-run ams_activate.sh with the previous release path, then start + status"
call :task_end

REM ============================ TASK[02] =====================================
REM FLAG: ams_backup.sh -z <sftp-url>
call :task_begin "02" "Back up to SFTP"
call :check_tool_remote "ams_backup.sh" "runs on the AMS server as amssys"
call :require_var "AMS_SFTP_TARGET" "set AMS_SFTP_TARGET='sftp://<host>/<path>/ams-backup.tar.gz'"
call :get_or "AMS_SFTP_TARGET" "sftp://<host>/<path>/ams-backup.tar.gz"
call :note "impact: read-only/low impact -- prefer key-based auth for the SFTP target"
call :show_run "sudo -iu amssys ams_backup.sh -z '!AMS_SFTP_TARGET!'"
call :note "success looks like: archive exists at the target path and the log confirms a clean run"
call :task_end

REM ============================ TASK[03] =====================================
REM FLAG: ams_set_sftp_port.sh --check
REM FLAG: ams_set_sftp_port.sh <port>
REM FLAG: ams_server restart
REM FLAG: ams_updatefirewall
call :task_begin "03" "Change SFTP port"
call :check_tool_remote "ams_set_sftp_port.sh" "runs on the AMS server (privileged)"
call :check_tool_remote "ams_server" "runs on the AMS server as amssys"
call :check_tool_remote "ams_updatefirewall" "runs on the AMS server as root"
call :require_var "AMS_SFTP_PORT" "set AMS_SFTP_PORT=<new-port> for your site"
call :get_or "AMS_SFTP_PORT" "2222"
call :note "impact: service/configuration change -- SFTP restarts on the new port"
call :show_run "ams_set_sftp_port.sh --check"
call :note "variant: set the port (example !AMS_SFTP_PORT!):"
call :show_run "ams_set_sftp_port.sh '!AMS_SFTP_PORT!'"
call :show_run "ams_server restart"
call :show_run "ams_updatefirewall"
call :note "back-out: re-run ams_set_sftp_port.sh with the previous port, then restart + ams_updatefirewall"
call :task_end

REM ============================ TASK[04] =====================================
REM FLAG: ams_cluster status --detailed
REM FLAG: ams_log_manager.sh --collect --category all --target all --destination <uri>
REM FLAG: ams_support.sh --domain app --command jstack --target all --destination <path>
REM FLAG: ams_support.sh --domain app --command jmap --target all --destination <path>
call :task_begin "04" "Collect a support bundle"
call :check_tool_remote "ams_cluster" "runs on the AMS server as amssys"
call :check_tool_remote "ams_log_manager.sh" "runs on the AMS server as amssys"
call :check_tool_remote "ams_support.sh" "runs on the AMS server as amssys"
call :note "impact: bundle may contain sensitive data; jstack/jmap add JVM load -- warn the NOC first"
call :show_run "ams_cluster status --detailed"
call :show_run "ams_log_manager.sh --collect --category all --target all --destination 'file:///tmp/ams-support.tar'"
call :show_run "ams_support.sh --domain app --command jstack --target all --destination '/tmp/ams-jstack.tar'"
call :note "variant: heap dump instead of (or after) threads -- take jstack BEFORE the heavier jmap:"
call :show_run "ams_support.sh --domain app --command jmap --target all --destination '/tmp/ams-jmap.tar'"
call :note "success looks like: both .tar files exist with non-trivial size; ship over a secure channel only"
call :task_end

REM ============================ TASK[05] =====================================
REM FLAG: ams_server stop
REM FLAG: ams_simplex_to_cluster.sh   (interactive)
REM FLAG: ams_updatefirewall
REM FLAG: ams_server start
REM FLAG: ams_cluster status --detailed
call :task_begin "05" "Convert simplex to cluster"
call :check_tool_remote "ams_server" "runs on the AMS server as amssys"
call :check_tool_remote "ams_simplex_to_cluster.sh" "runs on the AMS server as amssys (interactive)"
call :check_tool_remote "ams_updatefirewall" "runs on the AMS server as root"
call :check_tool_remote "ams_cluster" "runs on the AMS server as amssys"
call :note "impact: SERVICE-AFFECTING -- ams_simplex_to_cluster.sh is interactive:"
call :note "  have the cluster NIC, multicast addresses, and alternate data-server details on paper first"
call :show_run "ams_server stop"
call :show_run "ams_simplex_to_cluster.sh   # interactive -- answer its prompts (use ssh -t)"
call :show_run "ams_updatefirewall"
call :show_run "ams_server start"
call :show_run "ams_cluster status --detailed"
call :note "back-out: no automated de-conversion -- restore from the tested pre-change backup"
call :task_end

REM ============================ TASK[06] =====================================
REM FLAG: ams_db_defragment.sh all analyse
REM FLAG: ams_db_defragment.sh all execute
REM FLAG: ams_server stop
REM FLAG: ams_server start
call :task_begin "06" "Defragment database"
call :check_tool_remote "ams_server" "runs on the AMS server as amssys"
call :note "tool path: $AMSSCRIPTSDIR/ams_db_defragment.sh (AMSSCRIPTSDIR is on the amssys PATH context)"
set "R_AMSSCRIPTS="
for /f "delims=" %%v in ('ssh "%REMOTE%" "echo $AMSSCRIPTSDIR" 2^>nul') do set "R_AMSSCRIPTS=%%v"
if "!R_AMSSCRIPTS!"=="" (
    set "CUR_SKIP=1"
    call :log "  [MISSING] env var: AMSSCRIPTSDIR (on %REMOTE%)"
    echo - TASK[!CUR_ID!] !CUR_NAME!: AMSSCRIPTSDIR not set on %REMOTE%>> "%SKIPFILE%"
) else (
    call :log "  [ok] AMSSCRIPTSDIR='!R_AMSSCRIPTS!' (on %REMOTE%)"
    call :check_tool_remote "!R_AMSSCRIPTS!/ams_db_defragment.sh" "expected via $AMSSCRIPTSDIR on the AMS server"
)
call :note "impact: run ANALYSE any time; run EXECUTE only on the active data server in a maintenance window"
call :show_run "$AMSSCRIPTSDIR/ams_db_defragment.sh all analyse"
call :show_run "ams_server stop"
call :show_run "$AMSSCRIPTSDIR/ams_db_defragment.sh all execute"
call :show_run "ams_server start"
call :note "back-out: none -- defragmentation has no undo; restore from backup if execute causes problems"
call :task_end

REM ============================ TASK[07] =====================================
REM FLAG: ams_cluster status --detailed
REM FLAG: ams_cluster evacuate_ne <cluster-ip>
REM FLAG: ams_show_ne_balancing.sh -a <cluster-ip>
REM FLAG: ams_server stop maintenance
REM FLAG: ams_server start
REM FLAG: ams_cluster unevacuate_ne <cluster-ip> <weight>
call :task_begin "07" "Evacuate application server"
call :check_tool_remote "ams_cluster" "runs on the AMS server as amssys"
call :check_tool_remote "ams_show_ne_balancing.sh" "runs on the AMS server as amssys"
call :check_tool_remote "ams_server" "runs on the AMS server as amssys"
call :require_var "AMS_CLUSTER_IP" "set AMS_CLUSTER_IP=<cluster-ip> of the host to evacuate"
call :get_or "AMS_CLUSTER_IP" "<cluster-ip>"
call :note "impact: capacity/placement -- record placement and confirm remaining capacity BEFORE evacuating"
call :show_run "ams_cluster status --detailed"
call :show_run "ams_cluster evacuate_ne '!AMS_CLUSTER_IP!'"
call :show_run "ams_show_ne_balancing.sh -a '!AMS_CLUSTER_IP!'"
call :show_run "ams_server stop maintenance"
call :note "return-to-service sequence:"
call :show_run "ams_server start"
call :show_run "ams_cluster unevacuate_ne '!AMS_CLUSTER_IP!' 1"
call :show_run "ams_cluster status --detailed"
call :note "back-out: start, then unevacuate_ne with the RECORDED weight (rebalancing is not guaranteed identical)"
call :task_end

REM ============================ TASK[08] =====================================
REM FLAG: ams_switch_authentication_local
call :task_begin "08" "Fall back to local authentication"
call :check_tool_remote "ams_switch_authentication_local" "runs on the AMS server as amssys"
call :note "impact: security change -- use when LDAP/RADIUS failure blocks logins"
call :show_run "ams_switch_authentication_local"
call :note "back-out: restore the external auth afterwards per site procedure; record which config was active"
call :task_end

REM ============================ TASK[09] =====================================
REM FLAG: ams_cluster status --detailed
REM FLAG: ams_switch_active_dataserver
REM FLAG: ams_switch_active_dataserver -f   (automation only, with independent health checks)
call :task_begin "09" "Force data-server switchover"
call :check_tool_remote "ams_cluster" "runs on the AMS server as amssys"
call :check_tool_remote "ams_switch_active_dataserver" "runs on the AMS server as amssys"
call :note "impact: service-affecting -- the -f flag is for automation with independent health checks ONLY"
call :show_run "ams_cluster status --detailed"
call :show_run "ams_switch_active_dataserver"
call :note "variant (NOT for interactive use): ams_switch_active_dataserver -f"
call :show_run "ams_cluster status --detailed"
call :note "back-out: run ams_switch_active_dataserver again to switch back, verify with status --detailed"
call :task_end

REM ============================ TASK[10] =====================================
REM FLAG: ams_cluster stop
REM FLAG: ams_copy_datafiles --force --from-backup <path>
REM FLAG: ams_server start
REM FLAG: ams_server status all -l 30 -p 60
call :task_begin "10" "Migrate from backup"
call :check_tool_remote "ams_cluster" "runs on the AMS server as amssys"
call :check_tool_remote "ams_copy_datafiles" "runs on the AMS server (privileged)"
call :check_tool_remote "ams_server" "runs on the AMS server as amssys"
call :require_var "AMS_MIGRATION_BACKUP" "set AMS_MIGRATION_BACKUP=/absolute/path/source-backup.tar"
call :get_or "AMS_MIGRATION_BACKUP" "/absolute/path/source-backup.tar"
call :note "impact: HIGH and service-affecting -- install required plug-ins BEFORE the persistency copy"
call :show_run "ams_cluster stop"
call :show_run "ams_copy_datafiles --force --from-backup '!AMS_MIGRATION_BACKUP!'"
call :show_run "ams_server start"
call :show_run "ams_server status all -l 30 -p 60"
call :note "back-out: restore from the tested pre-change backup; this playbook overwrites data in place"
call :task_end

REM ============================ TASK[11] =====================================
REM FLAG: ams_support.sh --domain security --command killadminsessions
REM FLAG: ams_support.sh --domain security --command resetadminpwd
call :task_begin "11" "Recover administrator"
call :check_tool_remote "ams_support.sh" "runs on the AMS server as amssys"
call :note "impact: security-sensitive -- check release/setup restrictions first"
call :show_run "ams_support.sh --domain security --command killadminsessions"
call :show_run "ams_support.sh --domain security --command resetadminpwd"
call :note "afterwards: re-secure the account immediately (proper password, verify sessions)"
call :task_end

REM ============================ TASK[12] =====================================
REM FLAG: ams_restore.sh -n <archive>
REM FLAG: ams_install_license   (root/sudo)
REM FLAG: ams_server start
call :task_begin "12" "Restore on different hardware"
call :check_tool_remote "ams_restore.sh" "runs on the AMS server as amssys"
call :check_tool_remote "ams_install_license" "license install needs root/sudo on the server"
call :check_tool_remote "ams_server" "runs on the AMS server as amssys"
call :require_var "AMS_RESTORE_ARCHIVE" "set AMS_RESTORE_ARCHIVE=/backup/ams-data.tar"
call :get_or "AMS_RESTORE_ARCHIVE" "/backup/ams-data.tar"
call :note "impact: HIGH and service-affecting -- old licenses do not apply; install new-host licenses"
call :show_run "ams_restore.sh -n '!AMS_RESTORE_ARCHIVE!'"
call :show_run "sudo ams_install_license"
call :show_run "ams_server start"
call :note "back-out: restore from the pre-change backup of the target host"
call :task_end

REM ============================ TASK[13] =====================================
REM FLAG: ams_update_database_pwd.sh
call :task_begin "13" "Rotate database credentials"
call :check_tool_remote "ams_update_database_pwd.sh" "runs as amssys or root on the server"
call :note "impact: HIGH -- the script stops AMS, updates credentials, and AUTO-STARTS the cluster afterwards"
call :note "rule: new password <= 32 chars, no spaces. Do NOT manually restart afterwards."
call :show_run "ams_update_database_pwd.sh"
call :note "back-out: not reversible in place -- restore from the tested pre-change backup"
call :task_end

REM ============================ TASK[14] =====================================
REM FLAG: ams_cluster status --detailed
REM FLAG: ams_server version
REM FLAG: ams_backup.sh -z <path>
call :task_begin "14" "Take a pre-change backup"
call :check_tool_remote "ams_cluster" "runs on the AMS server as amssys"
call :check_tool_remote "ams_server" "runs on the AMS server as amssys"
call :check_tool_remote "ams_backup.sh" "runs on the AMS server as amssys"
call :require_var "AMS_BACKUP_PATH" "set AMS_BACKUP_PATH=/backup/prechange-ams.tar.gz"
call :get_or "AMS_BACKUP_PATH" "/backup/prechange-ams.tar.gz"
call :note "impact: read-only/low impact -- run before EVERY non-trivial change"
call :show_run "ams_cluster status --detailed"
call :show_run "ams_server version"
call :show_run "ams_backup.sh -z '!AMS_BACKUP_PATH!'"
call :note "success looks like: archive exists at the path and the log confirms a clean run"
call :task_end

REM ============================ TASK[15] =====================================
REM FLAG: ams_server version save --label <label> <path>
REM FLAG: ams_server version verify <path>
REM FLAG: ams_cluster status sw
call :task_begin "15" "Validate installed software"
call :check_tool_remote "ams_server" "runs on the AMS server as amssys"
call :check_tool_remote "ams_cluster" "runs on the AMS server as amssys"
call :require_var "AMS_GOLDEN_LABEL" "set AMS_GOLDEN_LABEL=GOLDEN983 (snapshot label)"
call :require_var "AMS_GOLDEN_PATH" "set AMS_GOLDEN_PATH=/secure/GoldenEMSSwConfig (snapshot path)"
call :get_or "AMS_GOLDEN_LABEL" "GOLDEN983"
call :get_or "AMS_GOLDEN_PATH" "/secure/GoldenEMSSwConfig"
call :note "impact: read-only -- save the golden snapshot once from a known-good system"
call :show_run "ams_server version save --label '!AMS_GOLDEN_LABEL!' '!AMS_GOLDEN_PATH!'"
call :show_run "ams_server version verify '!AMS_GOLDEN_PATH!'"
call :show_run "ams_cluster status sw"
call :note "success looks like: verify reports no differences; status sw shows agreement on all nodes"
call :task_end

REM ============================ TASK[16] =====================================
REM FLAG: curl --cacert <pem> https://<host>:8443/ams/services/UserManagementMgr
REM FLAG: curl --cacert <pem> https://<host>:8443/ams/schema/doc/html/index.html
call :task_begin "16" "Verify NBI over HTTPS"
call :check_tool_local "curl.exe" "Windows 10+ ships curl.exe; otherwise install it"
call :require_var "AMS_CA_PEM" "set AMS_CA_PEM to your site CA certificate path"
call :require_var "AMS_NBI_HOST" "set AMS_NBI_HOST=<host> (AMS northbound host)"
call :get_or "AMS_CA_PEM" "C:\path\ams-ca.pem"
call :get_or "AMS_NBI_HOST" "<host>"
call :note "impact: read-only -- proves the NBI answers over TLS before debugging any SOAP integration"
set "_curl1=curl.exe --cacert "!AMS_CA_PEM!" "https://!AMS_NBI_HOST!:8443/ams/services/UserManagementMgr""
set "_curl2=curl.exe --cacert "!AMS_CA_PEM!" "https://!AMS_NBI_HOST!:8443/ams/schema/doc/html/index.html""
call :show_local "%_curl1%"
call :show_local "%_curl2%"
call :note "success looks like: both endpoints answer (service descriptor + schema docs page load)"
call :task_end

REM ============================ TASK[17] =====================================
REM FLAG: ams_ne_cli -protocol
REM FLAG: ams_ne_cli -buffer
REM FLAG: ams_ne_cli <ne-list> <command-file> <output-file> <timeout>
call :task_begin "17" "NE CLI transport probes"
call :check_tool_remote "ams_ne_cli" "runs on the AMS server as amssys"
call :note "impact: probes are read-only; the full 4-arg form EXECUTES NE-native commands verbatim (review twice)"
call :show_run "ams_ne_cli -protocol"
call :show_run "ams_ne_cli -buffer"
call :require_var "NE_LIST" "set NE_LIST for the full form (NE target list file)"
call :require_var "NE_CMD_FILE" "set NE_CMD_FILE for the full form (NE-native command file)"
call :require_var "NE_OUT" "set NE_OUT for the full form (output file)"
call :require_var "NE_TIMEOUT" "set NE_TIMEOUT for the full form (seconds, e.g. 120)"
call :get_or "NE_LIST" "/tmp/ne-list.txt"
call :get_or "NE_CMD_FILE" "/tmp/commands.txt"
call :get_or "NE_OUT" "/tmp/ne_cli_out.txt"
call :get_or "NE_TIMEOUT" "120"
call :note "variant: full run against a target list (validate every line against the NE family command reference):"
call :show_run "ams_ne_cli '!NE_LIST!' '!NE_CMD_FILE!' '!NE_OUT!' '!NE_TIMEOUT!'"
call :task_end

REM ============================ TASK[18] =====================================
REM FLAG: ams_ne_mgr --help
REM FLAG: ams_ne_mgr [options] <input-file>
call :task_begin "18" "NE manager help and flags"
call :check_tool_remote "ams_ne_mgr" "runs on the AMS server as amssys"
call :note "impact: --help is read-only; the real run is provisioning (mass create/modify from a file)"
call :show_run "ams_ne_mgr --help"
call :note "gotcha from the guide: an IP-address change CANNOT be combined with other attribute changes -- split passes"
call :require_var "NE_MGR_INPUT" "set NE_MGR_INPUT=<input-file> to preview the real invocation"
call :get_or "NE_MGR_INPUT" "<input-file>"
call :show_run "ams_ne_mgr '!NE_MGR_INPUT!'"
call :task_end

REM ============================ TASK[19] =====================================
REM FLAG: ams_nebackup.sh <target>
call :task_begin "19" "Back up NE data"
call :check_tool_remote "ams_nebackup.sh" "runs on the AMS server as amssys"
call :require_var "NE_BACKUP_TARGET" "set NE_BACKUP_TARGET=/backup/ne-prechange.tar"
call :get_or "NE_BACKUP_TARGET" "/backup/ne-prechange.tar"
call :note "impact: writes a backup file (no live data changed)"
call :show_run "ams_nebackup.sh '!NE_BACKUP_TARGET!'"
call :task_end

REM ============================ TASK[20] =====================================
REM FLAG: ams_schedule_backup -int
REM FLAG: ams_schedule_backup
call :task_begin "20" "Schedule backups (interactive)"
call :check_tool_remote "ams_schedule_backup" "runs on the AMS server as amssys"
call :note "impact: scheduling change -- '-int' is INTERACTIVE (answers questions, builds the schedule)"
call :show_run "ams_schedule_backup -int   # interactive: answer its prompts (use ssh -t)"
call :show_run "ams_schedule_backup        # applies/activates the schedule"
call :note "gotcha: if the OS time zone ever changes, restart crond afterwards or the schedule silently shifts"
call :task_end

REM ============================ TASK[21] =====================================
REM FLAG: ams_sw_backup.sh <path>   (root)
call :task_begin "21" "Back up AMS software"
call :check_tool_remote "ams_sw_backup.sh" "runs as root on the server -- sudo is used"
call :require_var "SW_BACKUP_PATH" "set SW_BACKUP_PATH=/backup/ams-software"
call :get_or "SW_BACKUP_PATH" "/backup/ams-software"
call :note "impact: I/O intensive -- the script appends <hostname>.bin to the path you give it"
call :show_run "sudo ams_sw_backup.sh '!SW_BACKUP_PATH!'"
call :task_end

REM ============================ TASK[22] =====================================
REM FLAG: ams_check_ssl.sh
call :task_begin "22" "Check SSL/JBoss state"
call :check_tool_remote "ams_check_ssl.sh" "runs on the AMS server as amssys"
call :note "impact: read-only"
call :show_run "ams_check_ssl.sh"
call :task_end

REM ============================ TASK[23] =====================================
REM FLAG: ams_reset_logs.sh
call :task_begin "23" "Reset AMS logs"
call :check_tool_remote "ams_reset_logs.sh" "runs on the AMS server as amssys"
call :note "impact: DESTRUCTIVE TO LOGS -- never reset before collecting the evidence you need"
call :show_run "ams_reset_logs.sh"
call :task_end

REM ============================ TASK[24] =====================================
REM FLAG: ams_cluster start -force active
REM FLAG: ams_cluster start -force standby
REM FLAG: ams_cluster switch active
REM FLAG: ams_cluster switch standby
REM FLAG: ams_cluster switch active -force
REM FLAG: ams_server resetgeo
call :task_begin "24" "Geo redundancy commands"
call :check_tool_remote "ams_cluster" "runs on the AMS server as amssys"
call :check_tool_remote "ams_server" "runs on the AMS server as amssys"
call :note "impact: service-affecting -- -force bypasses role checks; verify the remote site first (dual-active risk)"
call :note "variant: start this site in a forced geo role:"
call :show_run "ams_cluster start -force active"
call :show_run "ams_cluster start -force standby"
call :note "variant: switch geo roles (plain, then forced):"
call :show_run "ams_cluster switch active"
call :show_run "ams_cluster switch standby"
call :show_run "ams_cluster switch active -force"
call :note "variant: clear the geo monitor timer -- ONLY after remediation:"
call :show_run "ams_server resetgeo"
call :task_end

REM ============================== REPORT =====================================
set /a TOTAL=PASS_COUNT+SKIP_COUNT
> "%REPORT%" echo # Dry-run report: AMS (Nokia 5520 AMS 9.8.3)
>>"%REPORT%" echo.
>>"%REPORT%" echo Generated (UTC): %NOWUTC%
>>"%REPORT%" echo Script: ams/scripts/dry-run.cmd (cmd.exe, via SSH to the AMS server)
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
echo AMS dry-run complete: %PASS_COUNT% PASS, %SKIP_COUNT% SKIP
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

:task_begin
set "CUR_ID=%~1"
set "CUR_NAME=%~2"
set "CUR_SKIP=0"
call :log ""
call :log "### TASK[%CUR_ID%]: %CUR_NAME%"
exit /b 0

:check_tool_remote
ssh "%REMOTE%" "command -v %~1" >nul 2>&1
if errorlevel 1 (
    set "CUR_SKIP=1"
    call :log "  [MISSING] tool: %~1 (on %REMOTE%)"
    call :log "            fix: %~2"
    echo - TASK[!CUR_ID!] !CUR_NAME!: missing tool '%~1' -- %~2>> "%SKIPFILE%"
) else (
    call :log "  [ok] tool present on %REMOTE%: %~1"
)
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

:get_or
if not defined %~1 set "%~1=%~2"
exit /b 0

:show_run
set "_line=  would run: ssh %REMOTE% "%~1""
call :log "%_line%"
exit /b 0

:show_local
set "_line=  would run: %~1"
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
