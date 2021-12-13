 # Created By Kyle Ericson

############Update to your Version String#############
$VERSION="2.5.0"
############Update to your Version String#############

# Download Banyan Install file
$progressPreference = 'silentlyContinue'
invoke-webrequest "https://www.banyanops.com/app/releases/Banyan-Setup-$($VERSION).exe" -outfile "C:\ProgramData\Banyan-Setup-$($VERSION).exe" -UseBasicParsing
$progressPreference = 'Continue'

# Quit Banyan
Stop-Process -Name Banyan -Force

# Install install-module RunAsUser 
install-module RunAsUser -Force

# Install Application
Start-Process C:\ProgramData\Banyan-Setup-$($VERSION).exe '/S' -Wait

# Open App as Current User
$scriptblock = {
& 'C:\Program Files\Banyan\Banyan.exe'
}
try{
Invoke-AsCurrentUser -scriptblock $scriptblock
} catch{
write-error "Something went wrong"
}
sleep 10

# Uninstall install-module RunAsUser 
Uninstall-Module RunAsUser -Force

exit 0 
