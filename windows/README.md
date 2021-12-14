# Install Banyan App on Windows

## Run as Administrator in PowerShell 

```
.\banyan-install.sh <APP_VERSION> <INVITE_CODE> <DEPLOY_KEY>
```

The `start_app` function only works if run as SYSTEM, so will fail in Admin Powershell. See instructions below to run as SYSTEM.


## Run as SYSTEM using PSTools

1. Download [PSTools](https://docs.microsoft.com/en-us/sysinternals/downloads/psexec) from here: https://download.sysinternals.com/files/PSTools.zip

2. Extract the PSTools.zip file to your admin executable path (such as: `C:\Windows\System32`)

3. Open Command Prompt (`cmd.exe`) as Administrator, and launch Powershell with a System account:

		psexec -i -s powershell.exe

4. In Powershell, navigate to this directory and run

		.\banyan-install.sh <APP_VERSION> <INVITE_CODE> <DEPLOY_KEY>
