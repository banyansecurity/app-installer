function Delete() {
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    $Path = ".\Banyan-Install-2.0.ps1"
    Write-Host $Path 
    Remove-Item $Path -force
} 

# Create Folders
New-Item -Path "C:\ProgramData" -Name "banyantemp" -ItemType "directory" -Force
New-Item -Path "C:\ProgramData" -Name "Banyan" -ItemType "directory" -Force

# Copy Json file saved to the current directory of this script
Copy-Item .\mdm-config.json -Destination C:\ProgramData\Banyan\ -Force

# Download Banyan Install file
$progressPreference = 'silentlyContinue'
invoke-webrequest "https://www.banyanops.com/app/releases/Banyan-Setup-2.5.0.exe" -outfile "C:\ProgramData\banyantemp\Banyan-Setup-2.5.0.exe" -UseBasicParsing
$progressPreference = 'Continue'

# Install install-module RunAsUser 
install-module RunAsUser -Force

# Install Application
Start-Process C:\ProgramData\banyantemp\Banyan-Setup-2.5.0.exe '/S' -Wait
& 'C:\Program Files\Banyan\Banyan.exe' --staged-deploy-key={INSERT DEPLOY KEY}
sleep 10

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
# Remove temp folder
Remove-Item -Path C:\ProgramData\banyantemp -Recurse -Force

# Deletes script off device
Delete
