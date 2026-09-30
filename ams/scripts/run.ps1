<#
.SYNOPSIS
    LIVE execution of every documented Nokia 5520 AMS 9.8.3 task (PowerShell).

.DESCRIPTION
    Runs the same task list as dry-run.ps1, in the same order, for real, via
    SSH to the AMS server (AMS_HOST env var or -AmsHost parameter).
    Read-only tasks run straight through. Every mutating, service-affecting,
    destructive, or security-sensitive step prints a warning and requires you
    to type "yes" before it runs. Fails fast on the first error.

    Run dry-run.ps1 first and resolve every SKIP before running this.
#>
[CmdletBinding()]
param(
    [string]$AmsHost = $env:AMS_HOST
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($AmsHost)) {
    Write-Host 'ERROR: set AMS_HOST (env var or -AmsHost), e.g. "amssys@ams-prod-01".'
    exit 1
}
$Remote = $AmsHost

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host 'ERROR: ssh not found. Install Win32 OpenSSH (Settings > Apps > Optional features).'
    exit 1
}

# ------------------------------------------------------------ helpers ---

function Invoke-Task {  # $Id, $Name
    param([string]$Id, [string]$Name)
    Write-Host ''
    Write-Host "### TASK[$Id]: $Name"
}

function Invoke-Step {  # print the remote command, run it over SSH, fail fast
    param([string]$RemoteCmd)
    Write-Host "  `$ ssh $Remote `"$RemoteCmd`""
    ssh $Remote $RemoteCmd
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED (exit $LASTEXITCODE): $RemoteCmd"
        exit 1
    }
}

function Invoke-Local {  # print the local command, run it, fail fast
    param([string]$Cmd)
    Write-Host "  `$ $Cmd"
    Invoke-Expression $Cmd
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED (exit $LASTEXITCODE): $Cmd"
        exit 1
    }
}

function Request-Confirm {  # $Warning -- returns only if the operator types exactly "yes"
    param([string]$Warning)
    Write-Host "  !! $Warning"
    $ans = Read-Host '  Type "yes" to continue, anything else aborts'
    if ($ans -ne 'yes') {
        Write-Host '  aborted by operator.'
        exit 1
    }
}

function Require-Var {  # $Name, $Description -- aborts if unset
    param([string]$Name, [string]$Description)
    $val = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($val)) {
        Write-Host "  ERROR: env var '$Name' is not set -- $Description"
        Write-Host '  Set it and re-run (dry-run.ps1 lists every variable).'
        exit 1
    }
    return $val
}

function Get-VarOr {  # $Name, $Default
    param([string]$Name, [string]$Default)
    $val = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($val)) { return $Default }
    return $val
}

function Write-Note {
    param([string]$Text)
    Write-Host "  note: $Text"
}

Write-Host '=================================================================='
Write-Host "LIVE RUN -- real commands against $Remote."
Write-Host 'Run dry-run.ps1 first and resolve every SKIP before proceeding.'
Write-Host '=================================================================='

# ---------------------------------------------------------------- tasks ---

# TASK[01]: Activate a release
Invoke-Task '01' 'Activate a release'
$rel = Require-Var 'AMS_RELEASE' 'AMS_RELEASE=/opt/ams/software/<release>'
Request-Confirm "SERVICE/CONFIGURATION CHANGE: activates release '$rel' (root) and starts the server."
Invoke-Step "sudo '$rel/bin/ams_activate.sh'"
Invoke-Step 'sudo -iu amssys ams_server start'
Invoke-Step 'sudo -iu amssys ams_server status'
Invoke-Step 'sudo -iu amssys ams_server version'

# TASK[02]: Back up to SFTP
Invoke-Task '02' 'Back up to SFTP'
$target = Require-Var 'AMS_SFTP_TARGET' "AMS_SFTP_TARGET='sftp://<host>/<path>/ams-backup.tar.gz'"
Write-Note "read-only/low impact -- writing backup archive to $target"
Invoke-Step "sudo -iu amssys ams_backup.sh -z '$target'"

# TASK[03]: Change SFTP port
Invoke-Task '03' 'Change SFTP port'
$port = Get-VarOr 'AMS_SFTP_PORT' '2222'
Write-Note "using SFTP port $port (override with AMS_SFTP_PORT)"
Invoke-Step 'ams_set_sftp_port.sh --check'
Request-Confirm "SERVICE/CONFIGURATION CHANGE: sets the SFTP port to $port and restarts the server."
Invoke-Step "ams_set_sftp_port.sh '$port'"
Invoke-Step 'ams_server restart'
Invoke-Step 'ams_updatefirewall'

# TASK[04]: Collect a support bundle
Invoke-Task '04' 'Collect a support bundle'
Write-Note 'bundle may contain SENSITIVE data; jstack adds JVM load -- warn the NOC first'
Invoke-Step 'ams_cluster status --detailed'
Invoke-Step "ams_log_manager.sh --collect --category all --target all --destination 'file:///tmp/ams-support.tar'"
Invoke-Step "ams_support.sh --domain app --command jstack --target all --destination '/tmp/ams-jstack.tar'"
Write-Note 'wrote /tmp/ams-support.tar and /tmp/ams-jstack.tar -- transfer over a secure channel only'
if ($env:AMS_JMAP -eq '1') {
    Request-Confirm 'HEAP DUMP: jmap is heavier than jstack and can briefly stall a loaded JVM.'
    Invoke-Step "ams_support.sh --domain app --command jmap --target all --destination '/tmp/ams-jmap.tar'"
} else {
    Write-Note 'skipping jmap heap dump (set AMS_JMAP=1 to include it)'
}

# TASK[05]: Convert simplex to cluster
Invoke-Task '05' 'Convert simplex to cluster'
Request-Confirm 'SERVICE-AFFECTING: stops the server and converts simplex to cluster. Have the cluster NIC, multicast addresses, and alternate data-server details on paper.'
Invoke-Step 'ams_server stop'
Write-Note 'ams_simplex_to_cluster.sh is interactive -- answer its prompts'
ssh -t $Remote 'ams_simplex_to_cluster.sh'
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: ams_simplex_to_cluster.sh'; exit 1 }
Invoke-Step 'ams_updatefirewall'
Invoke-Step 'ams_server start'
Invoke-Step 'ams_cluster status --detailed'

# TASK[06]: Defragment database
Invoke-Task '06' 'Defragment database'
Write-Note 'analysis runs any time; EXECUTE only on the active data server in a maintenance window'
Invoke-Step '$AMSSCRIPTSDIR/ams_db_defragment.sh all analyse'
Request-Confirm 'SERVICE-AFFECTING: stops the server and EXECUTES the database defragmentation (no undo).'
Invoke-Step 'ams_server stop'
Invoke-Step '$AMSSCRIPTSDIR/ams_db_defragment.sh all execute'
Invoke-Step 'ams_server start'

# TASK[07]: Evacuate application server
Invoke-Task '07' 'Evacuate application server'
$cip = Require-Var 'AMS_CLUSTER_IP' 'AMS_CLUSTER_IP=<cluster-ip> of the host to evacuate'
Invoke-Step 'ams_cluster status --detailed'
Write-Note 'record the current placement and confirm remaining capacity BEFORE evacuating'
Request-Confirm "CAPACITY/PLACEMENT IMPACT: evacuates NEs from $cip and stops the server in maintenance mode."
Invoke-Step "ams_cluster evacuate_ne '$cip'"
Invoke-Step "ams_show_ne_balancing.sh -a '$cip'"
Invoke-Step 'ams_server stop maintenance'
Write-Note 'returning the host to service:'
Invoke-Step 'ams_server start'
Invoke-Step "ams_cluster unevacuate_ne '$cip' 1"
Invoke-Step 'ams_cluster status --detailed'

# TASK[08]: Fall back to local authentication
Invoke-Task '08' 'Fall back to local authentication'
Request-Confirm 'SECURITY CHANGE: switches AMS authentication to local accounts.'
Invoke-Step 'ams_switch_authentication_local'
Write-Note 'restore the external auth afterwards per site procedure'

# TASK[09]: Force data-server switchover
Invoke-Task '09' 'Force data-server switchover'
Invoke-Step 'ams_cluster status --detailed'
Request-Confirm 'SERVICE-AFFECTING: switches the active data server to its peer.'
Invoke-Step 'ams_switch_active_dataserver'
Invoke-Step 'ams_cluster status --detailed'

# TASK[10]: Migrate from backup
Invoke-Task '10' 'Migrate from backup'
$mb = Require-Var 'AMS_MIGRATION_BACKUP' 'AMS_MIGRATION_BACKUP=/absolute/path/source-backup.tar'
Write-Note 'install required plug-ins BEFORE the persistency copy'
Request-Confirm "HIGH and SERVICE-AFFECTING: persistency copy from '$mb' overwrites data in place."
Invoke-Step 'ams_cluster stop'
Invoke-Step "ams_copy_datafiles --force --from-backup '$mb'"
Invoke-Step 'ams_server start'
Invoke-Step 'ams_server status all -l 30 -p 60'

# TASK[11]: Recover administrator
Invoke-Task '11' 'Recover administrator'
Request-Confirm 'SECURITY-SENSITIVE: kills stuck admin sessions and RESETS the admin password.'
Invoke-Step 'ams_support.sh --domain security --command killadminsessions'
Invoke-Step 'ams_support.sh --domain security --command resetadminpwd'
Write-Note 're-secure the account immediately (proper password, verify sessions)'

# TASK[12]: Restore on different hardware
Invoke-Task '12' 'Restore on different hardware'
$ra = Require-Var 'AMS_RESTORE_ARCHIVE' 'AMS_RESTORE_ARCHIVE=/backup/ams-data.tar'
Request-Confirm "HIGH and SERVICE-AFFECTING: restores '$ra' and installs new-host licenses."
Invoke-Step "ams_restore.sh -n '$ra'"
Invoke-Step 'sudo ams_install_license'
Invoke-Step 'ams_server start'

# TASK[13]: Rotate database credentials
Invoke-Task '13' 'Rotate database credentials'
Request-Confirm 'HIGH: stops AMS, rotates the database password (<=32 chars, no spaces), and AUTO-STARTS the cluster. Do not restart manually afterwards.'
Invoke-Step 'ams_update_database_pwd.sh'

# TASK[14]: Take a pre-change backup
Invoke-Task '14' 'Take a pre-change backup'
$bp = Get-VarOr 'AMS_BACKUP_PATH' '/backup/prechange-ams.tar.gz'
Write-Note "read-only/low impact -- writing $bp"
Invoke-Step 'ams_cluster status --detailed'
Invoke-Step 'ams_server version'
Invoke-Step "ams_backup.sh -z '$bp'"

# TASK[15]: Validate installed software
Invoke-Task '15' 'Validate installed software'
$gl = Require-Var 'AMS_GOLDEN_LABEL' 'AMS_GOLDEN_LABEL=GOLDEN983'
$gp = Require-Var 'AMS_GOLDEN_PATH' 'AMS_GOLDEN_PATH=/secure/GoldenEMSSwConfig'
Write-Note 'read-only -- compares the live system against the golden snapshot'
Invoke-Step "ams_server version save --label '$gl' '$gp'"
Invoke-Step "ams_server version verify '$gp'"
Invoke-Step 'ams_cluster status sw'

# TASK[16]: Verify NBI over HTTPS
Invoke-Task '16' 'Verify NBI over HTTPS'
$ca = Require-Var 'AMS_CA_PEM' 'AMS_CA_PEM=path to your site CA certificate'
$nh = Require-Var 'AMS_NBI_HOST' 'AMS_NBI_HOST=<host>'
Write-Note 'read-only -- proves the NBI answers over TLS'
Invoke-Local "curl.exe --cacert `"$ca`" `"https://${nh}:8443/ams/services/UserManagementMgr`""
Invoke-Local "curl.exe --cacert `"$ca`" `"https://${nh}:8443/ams/schema/doc/html/index.html`""

# TASK[17]: NE CLI transport probes
Invoke-Task '17' 'NE CLI transport probes'
Write-Note 'read-only probes:'
Invoke-Step 'ams_ne_cli -protocol'
Invoke-Step 'ams_ne_cli -buffer'
$nl = $env:NE_LIST; $cf = $env:NE_CMD_FILE; $of = $env:NE_OUT; $to = $env:NE_TIMEOUT
if ($nl -and $cf -and $of -and $to) {
    Request-Confirm "POTENTIALLY SERVICE-AFFECTING: executes NE-native commands verbatim on every target in $nl."
    Invoke-Step "ams_ne_cli '$nl' '$cf' '$of' '$to'"
} else {
    Write-Note 'skipping full 4-arg form (set NE_LIST, NE_CMD_FILE, NE_OUT, NE_TIMEOUT to enable)'
}

# TASK[18]: NE manager help and flags
Invoke-Task '18' 'NE manager help and flags'
Write-Note 'read-only -- documents the bulk-create flags'
Invoke-Step 'ams_ne_mgr --help'
Write-Note 'real runs use: ams_ne_mgr [options] <input-file> (provisioning -- not executed without NE_MGR_INPUT)'

# TASK[19]: Back up NE data
Invoke-Task '19' 'Back up NE data'
$nt = Require-Var 'NE_BACKUP_TARGET' 'NE_BACKUP_TARGET=/backup/ne-prechange.tar'
Write-Note 'writes a backup file (no live data changed)'
Invoke-Step "ams_nebackup.sh '$nt'"

# TASK[20]: Schedule backups (interactive)
Invoke-Task '20' 'Schedule backups (interactive)'
Request-Confirm 'SCHEDULING CHANGE: runs the INTERACTIVE scheduler; answer its prompts.'
ssh -t $Remote 'ams_schedule_backup -int'
if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED: ams_schedule_backup -int'; exit 1 }
Invoke-Step 'ams_schedule_backup'
Write-Note 'if the OS time zone ever changes, restart crond afterwards'

# TASK[21]: Back up AMS software
Invoke-Task '21' 'Back up AMS software'
$sp = Require-Var 'SW_BACKUP_PATH' 'SW_BACKUP_PATH=/backup/ams-software'
Request-Confirm 'I/O INTENSIVE (root): backs up the AMS software tree.'
Invoke-Step "sudo ams_sw_backup.sh '$sp'"

# TASK[22]: Check SSL/JBoss state
Invoke-Task '22' 'Check SSL/JBoss state'
Write-Note 'read-only'
Invoke-Step 'ams_check_ssl.sh'

# TASK[23]: Reset AMS logs
Invoke-Task '23' 'Reset AMS logs'
Request-Confirm 'DESTRUCTIVE TO LOGS: clears AMS logs. Collect the evidence you need FIRST.'
Invoke-Step 'ams_reset_logs.sh'

# TASK[24]: Geo redundancy commands
Invoke-Task '24' 'Geo redundancy commands'
Write-Note 'read-only status first:'
Invoke-Step 'ams_cluster status --detailed'
Request-Confirm 'SERVICE-AFFECTING GEO CHANGE: forced role commands bypass role checks -- verify the remote site first (dual-active risk).'
Write-Host '  choose geo action: [1] start -force active  [2] start -force standby  [3] switch active  [4] switch standby  [5] switch active -force  [6] resetgeo (only after remediation)  [0] skip'
$choice = Read-Host '  selection'
switch ($choice) {
    '1' { Invoke-Step 'ams_cluster start -force active' }
    '2' { Invoke-Step 'ams_cluster start -force standby' }
    '3' { Invoke-Step 'ams_cluster switch active' }
    '4' { Invoke-Step 'ams_cluster switch standby' }
    '5' { Invoke-Step 'ams_cluster switch active -force' }
    '6' { Invoke-Step 'ams_server resetgeo' }
    default { Write-Note 'skipping geo change' }
}

Write-Host ''
Write-Host '================================================================'
Write-Host 'AMS live run complete.'
Write-Host '================================================================'
