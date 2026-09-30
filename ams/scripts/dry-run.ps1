<#
.SYNOPSIS
    Verbose dry-run of every documented Nokia 5520 AMS 9.8.3 task (PowerShell).

.DESCRIPTION
    Walks the 16 operational playbooks from ams/guides/use-cases.md plus the
    documented flag variants from the other ams/guides/*.md files. For each
    task it prints the exact command(s) that WOULD run (fully quoted), checks
    prerequisites, and reports a PASS/SKIP verdict. Makes zero changes: no
    network calls beyond read-only SSH 'command -v' probes, no mutations,
    never prints or touches credentials.

    AMS commands run on the RHEL server as amssys; this script reaches it
    over SSH from Windows. Set AMS_HOST (env var or -AmsHost parameter).

.PARAMETER AmsHost
    SSH target for the AMS server, e.g. "amssys@ams-prod-01". Falls back to
    the AMS_HOST environment variable.

.REPORT
    Writes reports/dry-run-ams-<UTC>.md next to this script: summary up top,
    per-task verdicts, exact commands, and fix hints. The path is printed at
    the end. Exit 0 = all PASS, exit 1 = at least one SKIP.
#>
[CmdletBinding()]
param(
    [string]$AmsHost = $env:AMS_HOST
)

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------ helpers ---

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportDir  = Join-Path $ScriptDir 'reports'
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
$Stamp      = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$ReportPath = Join-Path $ReportDir "dry-run-ams-$Stamp.md"
$BodyLines  = New-Object System.Collections.Generic.List[string]

$script:PassCount = 0
$script:SkipCount = 0
$script:SkipDetails = New-Object System.Collections.Generic.List[string]

function Write-Log {
    param([string]$Text)
    Write-Host $Text
    $BodyLines.Add($Text)
}

function Start-Task {  # $Id, $Name
    param([string]$Id, [string]$Name)
    $script:CurId = $Id; $script:CurName = $Name
    $script:CurSkip = New-Object System.Collections.Generic.List[string]
    Write-Log ''
    Write-Log "### TASK[$Id]: $Name"
}

function Test-RemoteTool {  # $Tool, $Hint -- probe via SSH, read-only
    param([string]$Tool, [string]$Hint)
    ssh $script:Remote "command -v $Tool" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "  [ok] tool present on ${script:Remote}: $Tool"
    } else {
        $script:CurSkip.Add("missing tool '$Tool' on ${script:Remote} -- $Hint")
        Write-Log "  [MISSING] tool: $Tool (on ${script:Remote})"
        Write-Log "            fix: $Hint"
    }
}

function Test-LocalTool {  # $Tool, $Hint -- for curl.exe etc. on this machine
    param([string]$Tool, [string]$Hint)
    if (Get-Command $Tool -ErrorAction SilentlyContinue) {
        Write-Log "  [ok] tool present locally: $Tool"
    } else {
        $script:CurSkip.Add("missing local tool '$Tool' -- $Hint")
        Write-Log "  [MISSING] local tool: $Tool"
        Write-Log "            fix: $Hint"
    }
}

function Require-Var {  # $Name, $Description -- value IS echoed (never for secrets)
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

function Get-VarOr {  # $Name, $Default
    param([string]$Name, [string]$Default)
    $val = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($val)) { return $Default }
    return $val
}

function Show-Run {  # the exact remote command that would run
    param([string]$RemoteCmd)
    Write-Log "  would run: ssh $script:Remote `"$RemoteCmd`""
}

function Show-Local {  # the exact local command that would run
    param([string]$Cmd)
    Write-Log "  would run: $Cmd"
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

# ---------------------------------------------------------------- setup ---

if ([string]::IsNullOrEmpty($AmsHost)) {
    Write-Host 'ERROR: set AMS_HOST (env var or -AmsHost), e.g. "amssys@ams-prod-01".'
    exit 1
}
$script:Remote = $AmsHost

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host 'ERROR: ssh not found. Install Win32 OpenSSH (Settings > Apps > Optional features).'
    exit 1
}

Write-Log "# AMS dry-run -- $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
Write-Log "# via SSH to: $script:Remote (PowerShell)"

# ---------------------------------------------------------------- tasks ---

# --- TASK[01]: Activate a release ---
Start-Task '01' 'Activate a release'
# FLAG: ams_activate.sh <release-path>
# FLAG: ams_server start
# FLAG: ams_server status
# FLAG: ams_server version
Test-RemoteTool 'ams_activate.sh' 'activation runs on the AMS server; needs root/sudo there'
Test-RemoteTool 'ams_server' 'runs on the AMS server as amssys'
Require-Var 'AMS_RELEASE' 'set AMS_RELEASE=/opt/ams/software/<release> for your site'
$rel = Get-VarOr 'AMS_RELEASE' '/opt/ams/software/<release>'
Write-Note 'impact: service/configuration change -- activation runs as root, server control as amssys'
Show-Run "sudo '$rel/bin/ams_activate.sh'"
Show-Run 'sudo -iu amssys ams_server start'
Show-Run 'sudo -iu amssys ams_server status'
Write-Note 'variant: confirm the new release with: sudo -iu amssys ams_server version'
Show-Run 'sudo -iu amssys ams_server version'
Write-Note 'back-out: re-run ams_activate.sh with the previous release path, then start + status'
End-Task

# --- TASK[02]: Back up to SFTP ---
Start-Task '02' 'Back up to SFTP'
# FLAG: ams_backup.sh -z <sftp-url>
Test-RemoteTool 'ams_backup.sh' 'runs on the AMS server as amssys'
Require-Var 'AMS_SFTP_TARGET' "set AMS_SFTP_TARGET='sftp://<host>/<path>/ams-backup.tar.gz'"
$target = Get-VarOr 'AMS_SFTP_TARGET' 'sftp://<host>/<path>/ams-backup.tar.gz'
Write-Note 'impact: read-only/low impact -- prefer key-based auth for the SFTP target'
Show-Run "sudo -iu amssys ams_backup.sh -z '$target'"
Write-Note 'success looks like: archive exists at the target path and the log confirms a clean run'
End-Task

# --- TASK[03]: Change SFTP port ---
Start-Task '03' 'Change SFTP port'
# FLAG: ams_set_sftp_port.sh --check
# FLAG: ams_set_sftp_port.sh <port>
# FLAG: ams_server restart
# FLAG: ams_updatefirewall
Test-RemoteTool 'ams_set_sftp_port.sh' 'runs on the AMS server (privileged)'
Test-RemoteTool 'ams_server' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_updatefirewall' 'runs on the AMS server as root'
Require-Var 'AMS_SFTP_PORT' 'set AMS_SFTP_PORT=<new-port> for your site'
$port = Get-VarOr 'AMS_SFTP_PORT' '2222'
Write-Note 'impact: service/configuration change -- SFTP restarts on the new port'
Show-Run 'ams_set_sftp_port.sh --check'
Write-Note "variant: set the port (example $port):"
Show-Run "ams_set_sftp_port.sh '$port'"
Show-Run 'ams_server restart'
Show-Run 'ams_updatefirewall'
Write-Note 'back-out: re-run ams_set_sftp_port.sh with the previous port, then restart + ams_updatefirewall'
End-Task

# --- TASK[04]: Collect a support bundle ---
Start-Task '04' 'Collect a support bundle'
# FLAG: ams_cluster status --detailed
# FLAG: ams_log_manager.sh --collect --category all --target all --destination <uri>
# FLAG: ams_support.sh --domain app --command jstack --target all --destination <path>
# FLAG: ams_support.sh --domain app --command jmap --target all --destination <path>
Test-RemoteTool 'ams_cluster' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_log_manager.sh' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_support.sh' 'runs on the AMS server as amssys'
Write-Note 'impact: bundle may contain sensitive data; jstack/jmap add JVM load -- warn the NOC first'
Show-Run 'ams_cluster status --detailed'
Show-Run "ams_log_manager.sh --collect --category all --target all --destination 'file:///tmp/ams-support.tar'"
Show-Run "ams_support.sh --domain app --command jstack --target all --destination '/tmp/ams-jstack.tar'"
Write-Note 'variant: heap dump instead of (or after) threads -- take jstack BEFORE the heavier jmap:'
Show-Run "ams_support.sh --domain app --command jmap --target all --destination '/tmp/ams-jmap.tar'"
Write-Note 'success looks like: both .tar files exist with non-trivial size; ship over a secure channel only'
End-Task

# --- TASK[05]: Convert simplex to cluster ---
Start-Task '05' 'Convert simplex to cluster'
# FLAG: ams_server stop
# FLAG: ams_simplex_to_cluster.sh   (interactive)
# FLAG: ams_updatefirewall
# FLAG: ams_server start
# FLAG: ams_cluster status --detailed
Test-RemoteTool 'ams_server' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_simplex_to_cluster.sh' 'runs on the AMS server as amssys (interactive)'
Test-RemoteTool 'ams_updatefirewall' 'runs on the AMS server as root'
Test-RemoteTool 'ams_cluster' 'runs on the AMS server as amssys'
Write-Note 'impact: SERVICE-AFFECTING -- ams_simplex_to_cluster.sh is interactive:'
Write-Note '  have the cluster NIC, multicast addresses, and alternate data-server details on paper first'
Show-Run 'ams_server stop'
Show-Run 'ams_simplex_to_cluster.sh   # interactive -- answer its prompts (use ssh -t)'
Show-Run 'ams_updatefirewall'
Show-Run 'ams_server start'
Show-Run 'ams_cluster status --detailed'
Write-Note 'back-out: no automated de-conversion -- restore from the tested pre-change backup'
End-Task

# --- TASK[06]: Defragment database ---
Start-Task '06' 'Defragment database'
# FLAG: ams_db_defragment.sh all analyse
# FLAG: ams_db_defragment.sh all execute
# FLAG: ams_server stop
# FLAG: ams_server start
Test-RemoteTool 'ams_server' 'runs on the AMS server as amssys'
Write-Note 'tool path: $AMSSCRIPTSDIR/ams_db_defragment.sh (AMSSCRIPTSDIR is on the amssys PATH context)'
$amsScriptsDir = ssh $script:Remote 'echo $AMSSCRIPTSDIR' 2>$null
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($amsScriptsDir)) {
    Write-Log "  [ok] AMSSCRIPTSDIR='$($amsScriptsDir.Trim())' (on $script:Remote)"
    Test-RemoteTool "$($amsScriptsDir.Trim())/ams_db_defragment.sh" 'expected via $AMSSCRIPTSDIR on the AMS server'
} else {
    $script:CurSkip.Add("env var 'AMSSCRIPTSDIR' is not set on $script:Remote -- present for amssys there")
    Write-Log "  [MISSING] env var: AMSSCRIPTSDIR (on $script:Remote)"
}
Write-Note 'impact: run ANALYSE any time; run EXECUTE only on the active data server in a maintenance window'
Show-Run '$AMSSCRIPTSDIR/ams_db_defragment.sh all analyse'
Show-Run 'ams_server stop'
Show-Run '$AMSSCRIPTSDIR/ams_db_defragment.sh all execute'
Show-Run 'ams_server start'
Write-Note 'back-out: none -- defragmentation has no undo; restore from backup if execute causes problems'
End-Task

# --- TASK[07]: Evacuate application server ---
Start-Task '07' 'Evacuate application server'
# FLAG: ams_cluster status --detailed
# FLAG: ams_cluster evacuate_ne <cluster-ip>
# FLAG: ams_show_ne_balancing.sh -a <cluster-ip>
# FLAG: ams_server stop maintenance
# FLAG: ams_server start
# FLAG: ams_cluster unevacuate_ne <cluster-ip> <weight>
Test-RemoteTool 'ams_cluster' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_show_ne_balancing.sh' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_server' 'runs on the AMS server as amssys'
Require-Var 'AMS_CLUSTER_IP' 'set AMS_CLUSTER_IP=<cluster-ip> of the host to evacuate'
$cip = Get-VarOr 'AMS_CLUSTER_IP' '<cluster-ip>'
Write-Note 'impact: capacity/placement -- record placement and confirm remaining capacity BEFORE evacuating'
Show-Run 'ams_cluster status --detailed'
Show-Run "ams_cluster evacuate_ne '$cip'"
Show-Run "ams_show_ne_balancing.sh -a '$cip'"
Show-Run 'ams_server stop maintenance'
Write-Note 'return-to-service sequence:'
Show-Run 'ams_server start'
Show-Run "ams_cluster unevacuate_ne '$cip' 1"
Show-Run 'ams_cluster status --detailed'
Write-Note 'back-out: start, then unevacuate_ne with the RECORDED weight (rebalancing is not guaranteed identical)'
End-Task

# --- TASK[08]: Fall back to local authentication ---
Start-Task '08' 'Fall back to local authentication'
# FLAG: ams_switch_authentication_local
Test-RemoteTool 'ams_switch_authentication_local' 'runs on the AMS server as amssys'
Write-Note 'impact: security change -- use when LDAP/RADIUS failure blocks logins'
Show-Run 'ams_switch_authentication_local'
Write-Note 'back-out: restore the external auth afterwards per site procedure; record which config was active'
End-Task

# --- TASK[09]: Force data-server switchover ---
Start-Task '09' 'Force data-server switchover'
# FLAG: ams_cluster status --detailed
# FLAG: ams_switch_active_dataserver
# FLAG: ams_switch_active_dataserver -f   (automation only, with independent health checks)
Test-RemoteTool 'ams_cluster' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_switch_active_dataserver' 'runs on the AMS server as amssys'
Write-Note 'impact: service-affecting -- the -f flag is for automation with independent health checks ONLY'
Show-Run 'ams_cluster status --detailed'
Show-Run 'ams_switch_active_dataserver'
Write-Note 'variant (NOT for interactive use): ams_switch_active_dataserver -f'
Show-Run 'ams_cluster status --detailed'
Write-Note 'back-out: run ams_switch_active_dataserver again to switch back, verify with status --detailed'
End-Task

# --- TASK[10]: Migrate from backup ---
Start-Task '10' 'Migrate from backup'
# FLAG: ams_cluster stop
# FLAG: ams_copy_datafiles --force --from-backup <path>
# FLAG: ams_server start
# FLAG: ams_server status all -l 30 -p 60
Test-RemoteTool 'ams_cluster' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_copy_datafiles' 'runs on the AMS server (privileged)'
Test-RemoteTool 'ams_server' 'runs on the AMS server as amssys'
Require-Var 'AMS_MIGRATION_BACKUP' 'set AMS_MIGRATION_BACKUP=/absolute/path/source-backup.tar'
$mb = Get-VarOr 'AMS_MIGRATION_BACKUP' '/absolute/path/source-backup.tar'
Write-Note 'impact: HIGH and service-affecting -- install required plug-ins BEFORE the persistency copy'
Show-Run 'ams_cluster stop'
Show-Run "ams_copy_datafiles --force --from-backup '$mb'"
Show-Run 'ams_server start'
Show-Run 'ams_server status all -l 30 -p 60'
Write-Note 'back-out: restore from the tested pre-change backup; this playbook overwrites data in place'
End-Task

# --- TASK[11]: Recover administrator ---
Start-Task '11' 'Recover administrator'
# FLAG: ams_support.sh --domain security --command killadminsessions
# FLAG: ams_support.sh --domain security --command resetadminpwd
Test-RemoteTool 'ams_support.sh' 'runs on the AMS server as amssys'
Write-Note 'impact: security-sensitive -- check release/setup restrictions first'
Show-Run 'ams_support.sh --domain security --command killadminsessions'
Show-Run 'ams_support.sh --domain security --command resetadminpwd'
Write-Note 'afterwards: re-secure the account immediately (proper password, verify sessions)'
End-Task

# --- TASK[12]: Restore on different hardware ---
Start-Task '12' 'Restore on different hardware'
# FLAG: ams_restore.sh -n <archive>
# FLAG: ams_install_license   (root/sudo)
# FLAG: ams_server start
Test-RemoteTool 'ams_restore.sh' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_install_license' 'license install needs root/sudo on the server'
Test-RemoteTool 'ams_server' 'runs on the AMS server as amssys'
Require-Var 'AMS_RESTORE_ARCHIVE' 'set AMS_RESTORE_ARCHIVE=/backup/ams-data.tar'
$ra = Get-VarOr 'AMS_RESTORE_ARCHIVE' '/backup/ams-data.tar'
Write-Note 'impact: HIGH and service-affecting -- old licenses do not apply; install new-host licenses'
Show-Run "ams_restore.sh -n '$ra'"
Show-Run 'sudo ams_install_license'
Show-Run 'ams_server start'
Write-Note 'back-out: restore from the pre-change backup of the target host'
End-Task

# --- TASK[13]: Rotate database credentials ---
Start-Task '13' 'Rotate database credentials'
# FLAG: ams_update_database_pwd.sh
Test-RemoteTool 'ams_update_database_pwd.sh' 'runs as amssys or root on the server'
Write-Note 'impact: HIGH -- the script stops AMS, updates credentials, and AUTO-STARTS the cluster afterwards'
Write-Note 'rule: new password <= 32 chars, no spaces. Do NOT manually restart afterwards.'
Show-Run 'ams_update_database_pwd.sh'
Write-Note 'back-out: not reversible in place -- restore from the tested pre-change backup'
End-Task

# --- TASK[14]: Take a pre-change backup ---
Start-Task '14' 'Take a pre-change backup'
# FLAG: ams_cluster status --detailed
# FLAG: ams_server version
# FLAG: ams_backup.sh -z <path>
Test-RemoteTool 'ams_cluster' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_server' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_backup.sh' 'runs on the AMS server as amssys'
Require-Var 'AMS_BACKUP_PATH' 'set AMS_BACKUP_PATH=/backup/prechange-ams.tar.gz'
$bp = Get-VarOr 'AMS_BACKUP_PATH' '/backup/prechange-ams.tar.gz'
Write-Note 'impact: read-only/low impact -- run before EVERY non-trivial change'
Show-Run 'ams_cluster status --detailed'
Show-Run 'ams_server version'
Show-Run "ams_backup.sh -z '$bp'"
Write-Note 'success looks like: archive exists at the path and the log confirms a clean run'
End-Task

# --- TASK[15]: Validate installed software ---
Start-Task '15' 'Validate installed software'
# FLAG: ams_server version save --label <label> <path>
# FLAG: ams_server version verify <path>
# FLAG: ams_cluster status sw
Test-RemoteTool 'ams_server' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_cluster' 'runs on the AMS server as amssys'
Require-Var 'AMS_GOLDEN_LABEL' 'set AMS_GOLDEN_LABEL=GOLDEN983 (snapshot label)'
Require-Var 'AMS_GOLDEN_PATH' 'set AMS_GOLDEN_PATH=/secure/GoldenEMSSwConfig (snapshot path)'
$gl = Get-VarOr 'AMS_GOLDEN_LABEL' 'GOLDEN983'
$gp = Get-VarOr 'AMS_GOLDEN_PATH' '/secure/GoldenEMSSwConfig'
Write-Note 'impact: read-only -- save the golden snapshot once from a known-good system'
Show-Run "ams_server version save --label '$gl' '$gp'"
Show-Run "ams_server version verify '$gp'"
Show-Run 'ams_cluster status sw'
Write-Note 'success looks like: verify reports no differences; status sw shows agreement on all nodes'
End-Task

# --- TASK[16]: Verify NBI over HTTPS ---
Start-Task '16' 'Verify NBI over HTTPS'
# FLAG: curl --cacert <pem> https://<host>:8443/ams/services/UserManagementMgr
# FLAG: curl --cacert <pem> https://<host>:8443/ams/schema/doc/html/index.html
Test-LocalTool 'curl.exe' 'Windows 10+ ships curl.exe; otherwise install it'
Require-Var 'AMS_CA_PEM' 'set AMS_CA_PEM=C:\path\ams-ca.pem (site CA certificate)'
Require-Var 'AMS_NBI_HOST' 'set AMS_NBI_HOST=<host> (AMS northbound host)'
$ca = Get-VarOr 'AMS_CA_PEM' 'C:\path\ams-ca.pem'
$nh = Get-VarOr 'AMS_NBI_HOST' '<host>'
Write-Note 'impact: read-only -- proves the NBI answers over TLS before debugging any SOAP integration'
Show-Local "curl.exe --cacert `"$ca`" `"https://${nh}:8443/ams/services/UserManagementMgr`""
Show-Local "curl.exe --cacert `"$ca`" `"https://${nh}:8443/ams/schema/doc/html/index.html`""
Write-Note 'success looks like: both endpoints answer (service descriptor + schema docs page load)'
End-Task

# --- TASK[17]: NE CLI transport probes ---
Start-Task '17' 'NE CLI transport probes'
# FLAG: ams_ne_cli -protocol
# FLAG: ams_ne_cli -buffer
# FLAG: ams_ne_cli <ne-list> <command-file> <output-file> <timeout>
Test-RemoteTool 'ams_ne_cli' 'runs on the AMS server as amssys'
Write-Note 'impact: probes are read-only; the full 4-arg form EXECUTES NE-native commands verbatim (review twice)'
Show-Run 'ams_ne_cli -protocol'
Show-Run 'ams_ne_cli -buffer'
Require-Var 'NE_LIST' 'set NE_LIST for the full form (NE target list file)'
Require-Var 'NE_CMD_FILE' 'set NE_CMD_FILE for the full form (NE-native command file)'
Require-Var 'NE_OUT' 'set NE_OUT for the full form (output file)'
Require-Var 'NE_TIMEOUT' 'set NE_TIMEOUT for the full form (seconds, e.g. 120)'
$nl = Get-VarOr 'NE_LIST' '/tmp/ne-list.txt'
$cf = Get-VarOr 'NE_CMD_FILE' '/tmp/commands.txt'
$of = Get-VarOr 'NE_OUT' '/tmp/ne_cli_out.txt'
$to = Get-VarOr 'NE_TIMEOUT' '120'
Write-Note 'variant: full run against a target list (validate every line against the NE family command reference):'
Show-Run "ams_ne_cli '$nl' '$cf' '$of' '$to'"
End-Task

# --- TASK[18]: NE manager help and flags ---
Start-Task '18' 'NE manager help and flags'
# FLAG: ams_ne_mgr --help
# FLAG: ams_ne_mgr [options] <input-file>
Test-RemoteTool 'ams_ne_mgr' 'runs on the AMS server as amssys'
Write-Note 'impact: --help is read-only; the real run is provisioning (mass create/modify from a file)'
Show-Run 'ams_ne_mgr --help'
Write-Note 'gotcha from the guide: an IP-address change CANNOT be combined with other attribute changes -- split passes'
Require-Var 'NE_MGR_INPUT' 'set NE_MGR_INPUT=<input-file> to preview the real invocation'
$mi = Get-VarOr 'NE_MGR_INPUT' '<input-file>'
Show-Run "ams_ne_mgr '$mi'"
End-Task

# --- TASK[19]: Back up NE data ---
Start-Task '19' 'Back up NE data'
# FLAG: ams_nebackup.sh <target>
Test-RemoteTool 'ams_nebackup.sh' 'runs on the AMS server as amssys'
Require-Var 'NE_BACKUP_TARGET' 'set NE_BACKUP_TARGET=/backup/ne-prechange.tar'
$nt = Get-VarOr 'NE_BACKUP_TARGET' '/backup/ne-prechange.tar'
Write-Note 'impact: writes a backup file (no live data changed)'
Show-Run "ams_nebackup.sh '$nt'"
End-Task

# --- TASK[20]: Schedule backups (interactive) ---
Start-Task '20' 'Schedule backups (interactive)'
# FLAG: ams_schedule_backup -int
# FLAG: ams_schedule_backup
Test-RemoteTool 'ams_schedule_backup' 'runs on the AMS server as amssys'
Write-Note "impact: scheduling change -- '-int' is INTERACTIVE (answers questions, builds the schedule)"
Show-Run 'ams_schedule_backup -int   # interactive: answer its prompts (use ssh -t)'
Show-Run 'ams_schedule_backup        # applies/activates the schedule'
Write-Note 'gotcha: if the OS time zone ever changes, restart crond afterwards or the schedule silently shifts'
End-Task

# --- TASK[21]: Back up AMS software ---
Start-Task '21' 'Back up AMS software'
# FLAG: ams_sw_backup.sh <path>   (root)
Test-RemoteTool 'ams_sw_backup.sh' 'runs as root on the server -- sudo is used'
Require-Var 'SW_BACKUP_PATH' 'set SW_BACKUP_PATH=/backup/ams-software'
$sp = Get-VarOr 'SW_BACKUP_PATH' '/backup/ams-software'
Write-Note 'impact: I/O intensive -- the script appends <hostname>.bin to the path you give it'
Show-Run "sudo ams_sw_backup.sh '$sp'"
End-Task

# --- TASK[22]: Check SSL/JBoss state ---
Start-Task '22' 'Check SSL/JBoss state'
# FLAG: ams_check_ssl.sh
Test-RemoteTool 'ams_check_ssl.sh' 'runs on the AMS server as amssys'
Write-Note 'impact: read-only'
Show-Run 'ams_check_ssl.sh'
End-Task

# --- TASK[23]: Reset AMS logs ---
Start-Task '23' 'Reset AMS logs'
# FLAG: ams_reset_logs.sh
Test-RemoteTool 'ams_reset_logs.sh' 'runs on the AMS server as amssys'
Write-Note 'impact: DESTRUCTIVE TO LOGS -- never reset before collecting the evidence you need'
Show-Run 'ams_reset_logs.sh'
End-Task

# --- TASK[24]: Geo redundancy commands ---
Start-Task '24' 'Geo redundancy commands'
# FLAG: ams_cluster start -force active
# FLAG: ams_cluster start -force standby
# FLAG: ams_cluster switch active
# FLAG: ams_cluster switch standby
# FLAG: ams_cluster switch active -force
# FLAG: ams_server resetgeo
Test-RemoteTool 'ams_cluster' 'runs on the AMS server as amssys'
Test-RemoteTool 'ams_server' 'runs on the AMS server as amssys'
Write-Note 'impact: service-affecting -- -force bypasses role checks; verify the remote site first (dual-active risk)'
Write-Note 'variant: start this site in a forced geo role:'
Show-Run 'ams_cluster start -force active'
Show-Run 'ams_cluster start -force standby'
Write-Note 'variant: switch geo roles (plain, then forced):'
Show-Run 'ams_cluster switch active'
Show-Run 'ams_cluster switch standby'
Show-Run 'ams_cluster switch active -force'
Write-Note 'variant: clear the geo monitor timer -- ONLY after remediation:'
Show-Run 'ams_server resetgeo'
End-Task

# ---------------------------------------------------------------- report ---

$Total = $script:PassCount + $script:SkipCount
$Now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$ReportText = New-Object System.Collections.Generic.List[string]
$ReportText.Add('# Dry-run report: AMS (Nokia 5520 AMS 9.8.3)')
$ReportText.Add('')
$ReportText.Add("Generated (UTC): $Now")
$ReportText.Add('Script: ams/scripts/dry-run.ps1 (PowerShell, via SSH to the AMS server)')
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
Write-Host "AMS dry-run complete: $($script:PassCount) PASS, $($script:SkipCount) SKIP"
Write-Host "Report: $ReportPath"
Write-Host '================================================================'
if ($script:SkipCount -gt 0) { exit 1 } else { exit 0 }
