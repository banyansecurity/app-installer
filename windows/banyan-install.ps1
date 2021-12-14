# Run as administrator

$APP_VERSION=$args[0]
$INVITE_CODE=$args[1]
$DEPLOY_KEY=$args[2]

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (! $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"   
    exit 1
} else {
    Write-Host "Installing app for user: $env:USERNAME"
}

if (!$APP_VERSION -or !$INVITE_CODE -or !$DEPLOY_KEY) {
    Write-Host "Usage: "
    Write-Host "$PSCommandPath <APP_VERSION> <INVITE_CODE> <DEPLOY_KEY>"   
    exit 1
} else {
    Write-Host "Installing app version: $APP_VERSION"
    Write-Host "Installing with invite code: $INVITE_CODE"
    Write-Host "Installing using deploy key: $DEPLOY_KEY"
}

$global_profile_dir = "C:\ProgramData"

function create_config() {
    Write-Host "Creating mdm-config json file"

    $banyan_dir_name = "Banyan"
    $global_config_dir = $global_profile_dir + "\" + $banyan_dir_name
    $global_config_file = $global_config_dir + "\" + "mdm-config.json"

    # For Intune Deployments - Obtains email of user from Intune registry entry
    $intune_info = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
    $intune_user = ""
    $intune_email = ""
    if (Test-Path $intune_info) {
        Write-Host "Intune deployment - extracting user email"
        $ADJoinInfo = Get-ChildItem -path $intune_info
        $ADJoinInfo = $ADJoinInfo -replace "HKEY_LOCAL_MACHINE","HKLM:"
        $ADJoinUser = Get-ItemProperty -Path $ADJoinInfo
        $intune_email = $User.UserEmail
        $intune_user = $intune_email.Split("@")[0]
        Write-Host "Intune deployment - found user - $intune_email, $intune_user"
    }

    $json = [pscustomobject]@{ 
        mdm_invite_code = $INVITE_CODE
        mdm_deploy_user = $intune_user
        mdm_deploy_email = $intune_email 
        mdm_device_ownership = "C"
        mdm_present = $true
        mdm_vendor_name = "Intune"
        mdm_start_at_boot = $true
        mdm_hide_on_start = $true  

    } | ConvertTo-Json

    New-Item -Path $global_profile_dir -Name $banyan_dir_name -ItemType "directory" -Force
    Set-Content -Path $global_config_file -Value $json -NoNewLine
}

function download_extract() {
    Write-Host "Downloading installer EXE"    

    $tmp_dir_name = "banyantemp"
    $tmp_dir = $global_profile_dir + "\" + $tmp_dir_name

    New-Item -Path $global_profile_dir -Name $tmp_dir_name -ItemType "directory" -Force

    $dl_file = $tmp_dir + "\" + "Banyan-Setup-$APP_VERSION.exe"

    if (Test-Path $dl_file -PathType leaf) {
        Write-Host "Installer EXE already downloaded"    
    } else {
        $progressPreference = 'silentlyContinue'
        Invoke-Webrequest "https://www.banyanops.com/app/releases/Banyan-Setup-$APP_VERSION.exe" -outfile $dl_file -UseBasicParsing
        $progressPreference = 'Continue'
    }

    # Install Application
    Start-Process -FilePath $dl_file -ArgumentList "/S" -Wait
}

function stage() {
    Write-Host "Running staged deployment"
    Start-Process -FilePath "C:\Program Files\Banyan\Banyan.exe" -ArgumentList "--staged-deploy-key=$DEPLOY_KEY" -Wait
    Write-Host "Staged deployment done. Have the user start the Banyan app to complete registration."
}

function set_scheduled_task() {
    Write-Host "Creating ScheduledTask, so app launches upon user login"
    $ShedService = New-Object -comobject 'Schedule.Service'
    $ShedService.Connect()
    $Task = $ShedService.NewTask(0)
    $Task.RegistrationInfo.Description = 'Opens Banyan at login for any user'
    $Task.Settings.Enabled = $true
    $Task.Settings.AllowDemandStart = $true
    $trigger = $task.triggers.Create(9)
    $trigger.Enabled = $true
    $action = $Task.Actions.Create(0)
    $action.Path = '"C:\Program Files\Banyan\Banyan.exe"'
    $taskFolder = $ShedService.GetFolder("\")
    $taskFolder.RegisterTaskDefinition('Open Banyan', $Task , 6, 'Users', $null, 4)    
}

function start_app() {
    Write-Host "Starting the Banyan app as current user; this function needs to be run as SYSTEM (not just Admin)"

    Install-Module RunAsUser -Force

    $scriptblock = {
        & 'C:\Program Files\Banyan\Banyan.exe'
    }

    try {
        Invoke-AsCurrentUser -scriptblock $scriptblock
    } catch {
        Write-Warning "Couldn't start Banyan app"
    }
    sleep 10

    Uninstall-Module RunAsUser -Force
}

function stop_app() {
    Write-Host "Stopping Banyan app"
    Stop-Process -Name Banyan -Force
}

create_config
download_extract
stage
set_scheduled_task
start_app



