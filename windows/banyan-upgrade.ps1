###Enter Banyan Application Version (Example: 2.5.0)
$VERSION="X.Y.Z"

function download_extract() {
    # Download Banyan Install file
    $progressPreference = 'silentlyContinue'
    invoke-webrequest "https://www.banyanops.com/app/releases/Banyan-Setup-"$VERSION".exe" -outfile "C:\ProgramData\banyantemp\Banyan-Setup-"$VERSION".exe" -UseBasicParsing
    $progressPreference = 'Continue'
    # Install Application
    Start-Process C:\ProgramData\banyantemp\Banyan-Setup-"$VERSION".exe '/S' -Wait    
}

function launch() {
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

# Stop current Banyan app
Stop-Process -Name Banyan -Force

download_extract
launch