###Enter Banyan Application Version (Example: 2.5.0)
$VERSION="X.Y.Z"

function create_dir() {
    # Create Folders
    New-Item -Path "C:\ProgramData" -Name "banyantemp" -ItemType "directory" -Force
    New-Item -Path "C:\ProgramData" -Name "Banyan" -ItemType "directory" -Force
    # For Intune Deployments - Obtains email of user from Intune registry entry
    $ADJoinInfo = Get-ChildItem -path HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo
    $ADJoinInfo = $ADJoinInfo -replace "HKEY_LOCAL_MACHINE","HKLM:"
    $User = Get-ItemProperty -Path $ADJoinInfo
    $Email = $User.UserEmail
    echo $Email
    sleep 5
    # Creates mdm-config.json with the appropriate values
    $json = @{ mdm_invite_code = "INVITECODE"; mdm_deploy_user = $Email; mdm_deploy_email = $Email; mdm_start_at_boot = $true; mdm_present = $true; mdm_vendor_name = "Intune" } | ConvertTo-Json
    Set-Content -Path C:\ProgramData\Banyan\mdm-config.json -Value $json -NoNewLine
}

function download_extract() {
    # Download Banyan Install file
    $progressPreference = 'silentlyContinue'
    invoke-webrequest "https://www.banyanops.com/app/releases/Banyan-Setup-"$VERSION".exe" -outfile "C:\ProgramData\banyantemp\Banyan-Setup-"$VERSION".exe" -UseBasicParsing
    $progressPreference = 'Continue'
    # Install Application
    Start-Process C:\ProgramData\banyantemp\Banyan-Setup-"$VERSION".exe '/S' -Wait
}

function stage() {
    Start-Process C:\Program Files\Banyan\Banyan.exe '--staged-deploy-key={INSERT DEPLOY KEY}'
    sleep 10
}

function start() {
    # Install install-module RunAsUser 
    install-module RunAsUser -Force

    # Open App as Current User
    $scriptblock = {
        & 'C:\Program Files\Banyan\Banyan.exe'
    }

    try{
        Invoke-AsCurrentUser -scriptblock $scriptblock
    } catch {
        write-error "Something went wrong"
    }
    sleep 10

    # Uninstall install-module RunAsUser 
    Uninstall-Module RunAsUser -Force
}

create_dir
download_extract
stage
launch






