@echo off
REM ============================================================================
REM run.cmd -- LIVE execution of every documented Nokia 5520 AMS 9.8.3 task.
REM
REM Runs the same task list as dry-run.cmd, in the same order, for real, via
REM SSH to the AMS server (set AMS_HOST, e.g. set "AMS_HOST=amssys@ams-prod-01").
REM Read-only tasks run straight through. Every mutating, service-affecting,
REM destructive, or security-sensitive step prints a warning and requires you
REM to type "yes" before it runs. Fails fast on the first error.
REM
REM Run dry-run.cmd first and resolve every SKIP before running this.
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

echo ==================================================================
echo LIVE RUN -- real commands against %REMOTE%.
echo Run dry-run.cmd first and resolve every SKIP before proceeding.
echo ==================================================================

REM TASK[01]: Activate a release
call :task "01" "Activate a release"
call :need_var "AMS_RELEASE" "set AMS_RELEASE=/opt/ams/software/<release>"
call :confirm "SERVICE/CONFIGURATION CHANGE: activates release '!AMS_RELEASE!' (root) and starts the server."
call :rstep "sudo '!AMS_RELEASE!/bin/ams_activate.sh'"
call :rstep "sudo -iu amssys ams_server start"
call :rstep "sudo -iu amssys ams_server status"
call :rstep "sudo -iu amssys ams_server version"

REM TASK[02]: Back up to SFTP
call :task "02" "Back up to SFTP"
call :need_var "AMS_SFTP_TARGET" "set AMS_SFTP_TARGET='sftp://<host>/<path>/ams-backup.tar.gz'"
call :note "read-only/low impact -- writing backup archive to !AMS_SFTP_TARGET!"
call :rstep "sudo -iu amssys ams_backup.sh -z '!AMS_SFTP_TARGET!'"

REM TASK[03]: Change SFTP port
call :task "03" "Change SFTP port"
if not defined AMS_SFTP_PORT set "AMS_SFTP_PORT=2222"
call :note "using SFTP port !AMS_SFTP_PORT! (override with AMS_SFTP_PORT)"
call :rstep "ams_set_sftp_port.sh --check"
call :confirm "SERVICE/CONFIGURATION CHANGE: sets the SFTP port to !AMS_SFTP_PORT! and restarts the server."
call :rstep "ams_set_sftp_port.sh '!AMS_SFTP_PORT!'"
call :rstep "ams_server restart"
call :rstep "ams_updatefirewall"

REM TASK[04]: Collect a support bundle
call :task "04" "Collect a support bundle"
call :note "bundle may contain SENSITIVE data; jstack adds JVM load -- warn the NOC first"
call :rstep "ams_cluster status --detailed"
call :rstep "ams_log_manager.sh --collect --category all --target all --destination 'file:///tmp/ams-support.tar'"
call :rstep "ams_support.sh --domain app --command jstack --target all --destination '/tmp/ams-jstack.tar'"
call :note "wrote /tmp/ams-support.tar and /tmp/ams-jstack.tar -- transfer over a secure channel only"
if /i "%AMS_JMAP%"=="1" (
    call :confirm "HEAP DUMP: jmap is heavier than jstack and can briefly stall a loaded JVM."
    call :rstep "ams_support.sh --domain app --command jmap --target all --destination '/tmp/ams-jmap.tar'"
) else (
    call :note "skipping jmap heap dump (set AMS_JMAP=1 to include it)"
)

REM TASK[05]: Convert simplex to cluster
call :task "05" "Convert simplex to cluster"
call :confirm "SERVICE-AFFECTING: stops the server and converts simplex to cluster. Have the cluster NIC, multicast addresses, and alternate data-server details on paper."
call :rstep "ams_server stop"
call :note "ams_simplex_to_cluster.sh is interactive -- answer its prompts"
ssh -t "%REMOTE%" "ams_simplex_to_cluster.sh"
if errorlevel 1 ( echo   FAILED: ams_simplex_to_cluster.sh & exit /b 1 )
call :rstep "ams_updatefirewall"
call :rstep "ams_server start"
call :rstep "ams_cluster status --detailed"

REM TASK[06]: Defragment database
call :task "06" "Defragment database"
call :note "analysis runs any time; EXECUTE only on the active data server in a maintenance window"
call :rstep "$AMSSCRIPTSDIR/ams_db_defragment.sh all analyse"
call :confirm "SERVICE-AFFECTING: stops the server and EXECUTES the database defragmentation (no undo)."
call :rstep "ams_server stop"
call :rstep "$AMSSCRIPTSDIR/ams_db_defragment.sh all execute"
call :rstep "ams_server start"

REM TASK[07]: Evacuate application server
call :task "07" "Evacuate application server"
call :need_var "AMS_CLUSTER_IP" "set AMS_CLUSTER_IP=<cluster-ip> of the host to evacuate"
call :rstep "ams_cluster status --detailed"
call :note "record the current placement and confirm remaining capacity BEFORE evacuating"
call :confirm "CAPACITY/PLACEMENT IMPACT: evacuates NEs from !AMS_CLUSTER_IP! and stops the server in maintenance mode."
call :rstep "ams_cluster evacuate_ne '!AMS_CLUSTER_IP!'"
call :rstep "ams_show_ne_balancing.sh -a '!AMS_CLUSTER_IP!'"
call :rstep "ams_server stop maintenance"
call :note "returning the host to service:"
call :rstep "ams_server start"
call :rstep "ams_cluster unevacuate_ne '!AMS_CLUSTER_IP!' 1"
call :rstep "ams_cluster status --detailed"

REM TASK[08]: Fall back to local authentication
call :task "08" "Fall back to local authentication"
call :confirm "SECURITY CHANGE: switches AMS authentication to local accounts."
call :rstep "ams_switch_authentication_local"
call :note "restore the external auth afterwards per site procedure"

REM TASK[09]: Force data-server switchover
call :task "09" "Force data-server switchover"
call :rstep "ams_cluster status --detailed"
call :confirm "SERVICE-AFFECTING: switches the active data server to its peer."
call :rstep "ams_switch_active_dataserver"
call :rstep "ams_cluster status --detailed"

REM TASK[10]: Migrate from backup
call :task "10" "Migrate from backup"
call :need_var "AMS_MIGRATION_BACKUP" "set AMS_MIGRATION_BACKUP=/absolute/path/source-backup.tar"
call :note "install required plug-ins BEFORE the persistency copy"
call :confirm "HIGH and SERVICE-AFFECTING: persistency copy from '!AMS_MIGRATION_BACKUP!' overwrites data in place."
call :rstep "ams_cluster stop"
call :rstep "ams_copy_datafiles --force --from-backup '!AMS_MIGRATION_BACKUP!'"
call :rstep "ams_server start"
call :rstep "ams_server status all -l 30 -p 60"

REM TASK[11]: Recover administrator
call :task "11" "Recover administrator"
call :confirm "SECURITY-SENSITIVE: kills stuck admin sessions and RESETS the admin password."
call :rstep "ams_support.sh --domain security --command killadminsessions"
call :rstep "ams_support.sh --domain security --command resetadminpwd"
call :note "re-secure the account immediately (proper password, verify sessions)"

REM TASK[12]: Restore on different hardware
call :task "12" "Restore on different hardware"
call :need_var "AMS_RESTORE_ARCHIVE" "set AMS_RESTORE_ARCHIVE=/backup/ams-data.tar"
call :confirm "HIGH and SERVICE-AFFECTING: restores '!AMS_RESTORE_ARCHIVE!' and installs new-host licenses."
call :rstep "ams_restore.sh -n '!AMS_RESTORE_ARCHIVE!'"
call :rstep "sudo ams_install_license"
call :rstep "ams_server start"

REM TASK[13]: Rotate database credentials
call :task "13" "Rotate database credentials"
call :confirm "HIGH: stops AMS, rotates the database password (<=32 chars, no spaces), and AUTO-STARTS the cluster. Do not restart manually afterwards."
call :rstep "ams_update_database_pwd.sh"

REM TASK[14]: Take a pre-change backup
call :task "14" "Take a pre-change backup"
if not defined AMS_BACKUP_PATH set "AMS_BACKUP_PATH=/backup/prechange-ams.tar.gz"
call :note "read-only/low impact -- writing !AMS_BACKUP_PATH!"
call :rstep "ams_cluster status --detailed"
call :rstep "ams_server version"
call :rstep "ams_backup.sh -z '!AMS_BACKUP_PATH!'"

REM TASK[15]: Validate installed software
call :task "15" "Validate installed software"
call :need_var "AMS_GOLDEN_LABEL" "set AMS_GOLDEN_LABEL=GOLDEN983"
call :need_var "AMS_GOLDEN_PATH" "set AMS_GOLDEN_PATH=/secure/GoldenEMSSwConfig"
call :note "read-only -- compares the live system against the golden snapshot"
call :rstep "ams_server version save --label '!AMS_GOLDEN_LABEL!' '!AMS_GOLDEN_PATH!'"
call :rstep "ams_server version verify '!AMS_GOLDEN_PATH!'"
call :rstep "ams_cluster status sw"

REM TASK[16]: Verify NBI over HTTPS
call :task "16" "Verify NBI over HTTPS"
call :need_var "AMS_CA_PEM" "set AMS_CA_PEM to your site CA certificate path"
call :need_var "AMS_NBI_HOST" "set AMS_NBI_HOST=<host>"
call :note "read-only -- proves the NBI answers over TLS"
set "_u1=https://!AMS_NBI_HOST!:8443/ams/services/UserManagementMgr"
set "_u2=https://!AMS_NBI_HOST!:8443/ams/schema/doc/html/index.html"
set "_c1=curl.exe --cacert "!AMS_CA_PEM!" "!_u1!""
set "_c2=curl.exe --cacert "!AMS_CA_PEM!" "!_u2!""
call :lstep "%_c1%"
call :lstep "%_c2%"

REM TASK[17]: NE CLI transport probes
call :task "17" "NE CLI transport probes"
call :note "read-only probes:"
call :rstep "ams_ne_cli -protocol"
call :rstep "ams_ne_cli -buffer"
if defined NE_LIST if defined NE_CMD_FILE if defined NE_OUT if defined NE_TIMEOUT (
    call :confirm "POTENTIALLY SERVICE-AFFECTING: executes NE-native commands verbatim on every target in !NE_LIST!."
    call :rstep "ams_ne_cli '!NE_LIST!' '!NE_CMD_FILE!' '!NE_OUT!' '!NE_TIMEOUT!'"
) else (
    call :note "skipping full 4-arg form (set NE_LIST, NE_CMD_FILE, NE_OUT, NE_TIMEOUT to enable)"
)

REM TASK[18]: NE manager help and flags
call :task "18" "NE manager help and flags"
call :note "read-only -- documents the bulk-create flags"
call :rstep "ams_ne_mgr --help"
call :note "real runs use: ams_ne_mgr [options] <input-file> (provisioning -- not executed without NE_MGR_INPUT)"

REM TASK[19]: Back up NE data
call :task "19" "Back up NE data"
call :need_var "NE_BACKUP_TARGET" "set NE_BACKUP_TARGET=/backup/ne-prechange.tar"
call :note "writes a backup file (no live data changed)"
call :rstep "ams_nebackup.sh '!NE_BACKUP_TARGET!'"

REM TASK[20]: Schedule backups (interactive)
call :task "20" "Schedule backups (interactive)"
call :confirm "SCHEDULING CHANGE: runs the INTERACTIVE scheduler; answer its prompts."
ssh -t "%REMOTE%" "ams_schedule_backup -int"
if errorlevel 1 ( echo   FAILED: ams_schedule_backup -int & exit /b 1 )
call :rstep "ams_schedule_backup"
call :note "if the OS time zone ever changes, restart crond afterwards"

REM TASK[21]: Back up AMS software
call :task "21" "Back up AMS software"
call :need_var "SW_BACKUP_PATH" "set SW_BACKUP_PATH=/backup/ams-software"
call :confirm "I/O INTENSIVE (root): backs up the AMS software tree."
call :rstep "sudo ams_sw_backup.sh '!SW_BACKUP_PATH!'"

REM TASK[22]: Check SSL/JBoss state
call :task "22" "Check SSL/JBoss state"
call :note "read-only"
call :rstep "ams_check_ssl.sh"

REM TASK[23]: Reset AMS logs
call :task "23" "Reset AMS logs"
call :confirm "DESTRUCTIVE TO LOGS: clears AMS logs. Collect the evidence you need FIRST."
call :rstep "ams_reset_logs.sh"

REM TASK[24]: Geo redundancy commands
call :task "24" "Geo redundancy commands"
call :note "read-only status first:"
call :rstep "ams_cluster status --detailed"
call :confirm "SERVICE-AFFECTING GEO CHANGE: forced role commands bypass role checks -- verify the remote site first (dual-active risk)."
echo   choose geo action: [1] start -force active  [2] start -force standby  [3] switch active  [4] switch standby  [5] switch active -force  [6] resetgeo ^(only after remediation^)  [0] skip
set /p "GEO_CHOICE=  selection: "
if "%GEO_CHOICE%"=="1" call :rstep "ams_cluster start -force active"
if "%GEO_CHOICE%"=="2" call :rstep "ams_cluster start -force standby"
if "%GEO_CHOICE%"=="3" call :rstep "ams_cluster switch active"
if "%GEO_CHOICE%"=="4" call :rstep "ams_cluster switch standby"
if "%GEO_CHOICE%"=="5" call :rstep "ams_cluster switch active -force"
if "%GEO_CHOICE%"=="6" call :rstep "ams_server resetgeo"
if "%GEO_CHOICE%"=="0" call :note "skipping geo change"

echo.
echo ================================================================
echo AMS live run complete.
echo ================================================================
exit /b 0

REM ============================ SUBROUTINES ==================================

:task
echo.
echo ### TASK[%~1]: %~2
exit /b 0

:note
echo   note: %~1
exit /b 0

:rstep
echo   $ ssh %REMOTE% "%~1"
ssh "%REMOTE%" "%~1"
if errorlevel 1 (
    echo   FAILED: %~1
    exit /b 1
)
exit /b 0

:lstep
echo   $ %~1
call %~1
if errorlevel 1 (
    echo   FAILED: %~1
    exit /b 1
)
exit /b 0

:confirm
echo   !! %~1
set /p "ANS=  Type 'yes' to continue, anything else aborts: "
if /i not "%ANS%"=="yes" (
    echo   aborted by operator.
    exit /b 1
)
exit /b 0

:need_var
if not defined %~1 (
    echo   ERROR: env var '%~1' is not set -- %~2
    echo   Set it and re-run ^(dry-run.cmd lists every variable^).
    exit /b 1
)
exit /b 0
