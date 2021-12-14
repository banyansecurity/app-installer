# Banyan App Installer

Automate installation of Banyan App on end-user devices.


## MacOS

To test, launch a terminal and run `banyan-macos.sh`.

```
sudo ./banyan-macos.sh <APP_VERSION> <INVITE_CODE> <DEPLOY_KEY>
```


## Windows

### Run as Admin in PowerShell

To test, launch Powershell as SYSTEM using PSTools, and run `banyan-windows.ps1`

1. Download [PSTools](https://docs.microsoft.com/en-us/sysinternals/downloads/psexec) from here: https://download.sysinternals.com/files/PSTools.zip

2. Extract the PSTools.zip file to your admin executable path (such as: `C:\Windows\System32`)

3. Open Command Prompt (`cmd.exe`) as Administrator, and launch Powershell with a System account:

		psexec -i -s powershell.exe

4. In Powershell, navigate to this directory and run

		.\banyan-windows.ps1 <APP_VERSION> <INVITE_CODE> <DEPLOY_KEY>


We use PSTools and not just Admin Powershell because the `start_app` function only works if run as SYSTEM.