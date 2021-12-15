# Banyan App Installer

Automate installation of Banyan App on end-user devices.

In the Banyan Command Center, navigate to **Settings** > **App Deployment**. Note down your org-specific app deployment parameters for use in the scripts below:
- Invite Code
- MDM Deployment Key

The scripts will download the *latest Banyan app* version and install it using a "Zero Touch" flow. The scripts also allow you to (optionally) specify the exact app version to install.


## MacOS

To test, launch a terminal and run `banyan-macos.sh`.

```
sudo ./banyan-macos.sh <INVITE_CODE> <DEPLOY_KEY> <APP_VERSION (optional)>
```


## Windows

To test, launch Powershell as SYSTEM using PSTools, and run `banyan-windows.ps1`

1. Download [PSTools](https://docs.microsoft.com/en-us/sysinternals/downloads/psexec) from here: https://download.sysinternals.com/files/PSTools.zip

2. Extract the PSTools.zip file to your admin executable path (such as: `C:\Windows\System32`)

3. Open Command Prompt (`cmd.exe`) as Administrator, and launch Powershell with a System account:

		psexec -i -s powershell.exe

4. In Powershell, navigate to this directory and run

		.\banyan-windows.ps1 <INVITE_CODE> <DEPLOY_KEY> <APP_VERSION (optional)>

We use PSTools (and not just Admin Powershell) because: (a) that's how Intune runs, and (b) the `start_app` function only works if run as SYSTEM.
