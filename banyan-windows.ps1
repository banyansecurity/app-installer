# Run as administrator

################################################################################
# Banyan Zero Touch Installation
# Confirm or update the following variables prior to running the script

# Deployment Information
# Obtain from the Banyan admin console: Settings > App Deployment
$INVITE_CODE = $args[0]
$DEPLOYMENT_KEY = $args[1]
$APP_VERSION = $args[2]

# Device Registration and Banyan App Configuration
# Check docs for more options and details:
# https://docs.banyansecurity.io/docs/feature-guides/manage-users-and-devices/device-managers/distribute-desktopapp/#mdm-config-json
$DEVICE_OWNERSHIP = "S"
$CA_CERTS_PREINSTALLED = $false
$SKIP_CERT_SUPPRESSION = $false
$IS_MANAGED_DEVICE = $false
$DEVICE_MANAGER_NAME = ""
$HIDE_SERVICES = $false
$DISABLE_QUIT = $false
$START_AT_BOOT = $true
$AUTO_LOGIN = $false
$HIDE_ON_START = $true
$DISABLE_AUTO_UPDATE = $false

# User Information for Device Certificate
$MULTI_USER = $true

# Preview Feature: Allow App via NetFirewallRule for Windows Firewall.
$ALLOW_APP = $false


################################################################################


$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (! $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be with admin privilege"
    exit 1
}

if (!$INVITE_CODE -or !$DEPLOYMENT_KEY) {
    Write-Host "Usage: "
    Write-Host "$PSCommandPath <INVITE_CODE> <DEPLOYMENT_KEY> <APP_VERSION (optional>"
    exit 1
}

if (!$APP_VERSION) {
    Write-Host "Checking for latest version of app"
    $APP_VERSION = if ((Invoke-RestMethod -Uri "https://www.banyanops.com/app/releases/latest.yml") -match "version: (.+)") {$matches[1].Trim()}
}

Write-Host "Installing with invite code: $INVITE_CODE"
Write-Host "Installing using deploy key: *****"
Write-Host "Installing app version: $APP_VERSION"

$logged_on_user = Get-WMIObject -class Win32_ComputerSystem | Select-Object -expand UserName
Write-Host "Installing app for user: $logged_on_user"

$global_profile_dir = "C:\ProgramData"




$MY_USER = ""
$MY_EMAIL = ""
function get_user_email() {
    if (!$MULTI_USER) {
        # for a single user device, assumes you can get user and email because device is joined to an
        # Azure AD domain: https://nerdymishka.com/articles/azure-ad-domain-join-registry-keys/
        # (you may use other techniques here as well)
        $intune_info = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
        if (Test-Path $intune_info) {
            Write-Host "Extracting user email from: $intune_info"
            $ADJoinInfo = Get-ChildItem -path $intune_info
            $ADJoinInfo = $ADJoinInfo -replace "HKEY_LOCAL_MACHINE","HKLM:"
            $ADJoinUser = Get-ItemProperty -Path $ADJoinInfo
            $script:MY_EMAIL = $ADJoinUser.UserEmail
            $script:MY_USER = $MY_EMAIL.Split("@")[0]
        }
    }
    Write-Host "Installing for user with name: $MY_USER"
    Write-Host "Installing for user with email: $MY_EMAIL"
    if (!$MY_EMAIL) {
        Write-Host "No user specified - device certificate will be issued to the default **STAGED USER**"
    }
}


function create_config() {
    Write-Host "Creating mdm-config json file"

    $banyan_dir_name = "Banyan"
    $global_config_dir = $global_profile_dir + "\" + $banyan_dir_name
    $global_config_file = $global_config_dir + "\" + "mdm-config.json"

    $json = [pscustomobject]@{
        mdm_invite_code = $INVITE_CODE
        mdm_deploy_user = $MY_USER
        mdm_deploy_email = $MY_EMAIL
        mdm_device_ownership = $DEVICE_OWNERSHIP
        mdm_ca_certs_preinstalled = $CA_CERTS_PREINSTALLED
        mdm_skip_cert_suppression = $SKIP_CERT_SUPPRESSION
        mdm_present = $IS_MANAGED_DEVICE
        mdm_vendor_name = $DEVICE_MANAGER_NAME
        mdm_hide_services = $HIDE_SERVICES
        mdm_disable_quit = $DISABLE_QUIT
        mdm_start_at_boot = $START_AT_BOOT
        mdm_auto_login = $AUTO_LOGIN
        mdm_hide_on_start = $HIDE_ON_START
        mdm_disable_auto_update = $DISABLE_AUTO_UPDATE
    } | ConvertTo-Json

    New-Item -Path $global_profile_dir -Name $banyan_dir_name -ItemType "directory" -Force | Out-Null
    Set-Content -Path $global_config_file -Value $json -NoNewLine
}


function download_install() {
    Write-Host "Downloading installer EXE"

    $tmp_dir_name = "banyantemp"
    $tmp_dir = $global_profile_dir + "\" + $tmp_dir_name

    New-Item -Path $global_profile_dir -Name $tmp_dir_name -ItemType "directory" -Force | Out-Null

    $dl_file = $tmp_dir + "\" + "Banyan-Setup-$APP_VERSION.exe"

    $progressPreference = 'silentlyContinue'
    Invoke-Webrequest "https://www.banyanops.com/app/releases/Banyan-Setup-$APP_VERSION.exe" -outfile $dl_file -UseBasicParsing
    $progressPreference = 'Continue'

    Write-Host "Run installer"
    Start-Process -FilePath $dl_file -ArgumentList "/S" -Wait
    Start-Sleep -Seconds 3
}


function stage() {
    Write-Host "Running staged deployment"
    $process = Start-Process -FilePath "C:\Program Files\Banyan\resources\bin\banyanapp-admin.exe" -ArgumentList "stage --key=$DEPLOYMENT_KEY" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Host "Error during staged deployment"
        exit 1
    }
    Start-Sleep -Seconds 3
    Write-Host "Staged deployment done. Have the logged_on_user start the Banyan app to complete registration."
}


function create_scheduled_task($task_name) {
    Write-Host "Creating ScheduledTask $task_name for logged_on_user, so app launches upon next user login"
    $action = New-ScheduledTaskAction -Execute "C:\Program Files\Banyan\Banyan.exe"
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId $logged_on_user
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal
    Register-ScheduledTask $task_name -InputObject $task
}

function delete_scheduled_task($task_name) {
    Write-Host "Deleting ScheduledTask $task_name"
    Unregister-ScheduledTask -TaskName $task_name -Confirm:$false
}

# since Windows doesn't have "su - username", we use scheduled_task to launch Banyan app as logged_on user
function start_app() {
    Write-Host "Running ScheduledTask to start the Banyan app as: $logged_on_user"
    $task_name = "StartBanyanTemp"
    create_scheduled_task($task_name)
    Start-ScheduledTask -TaskName $task_name
    Start-Sleep -Seconds 5
    delete_scheduled_task($task_name)
}


function stop_app() {
    Write-Host "Stopping Banyan app"
    Get-Process -Name Banyan -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
}

function allow_app() {
    if ($ALLOW_APP) {
        New-NetFirewallRule `
            -DisplayName "SonicWall-CSE-App" `
            -Program "C:\Program Files\Banyan\Banyan.exe" `
            -Direction Outbound `
            -Action Allow `
            -Profile Public,Private,Domain
        }
}

if (($INVITE_CODE -eq "upgrade") -and ($DEPLOYMENT_KEY -eq "upgrade")) {
    Write-Host "Running upgrade flow"
    stop_app
    download_install
    start_app
} else {
    Write-Host "Running zero-touch install flow"
    stop_app
    get_user_email
    create_config
    download_install
    stage
    create_config
    allow_app
    start_app
}
