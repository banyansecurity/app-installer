# Banyan App Installer

Automate installation of Banyan App on end-user devices.

In the Banyan Command Center, navigate to **Settings** > **App Deployment**. Note down your org-specific app deployment parameters for use in the scripts below:
- Invite Code
- MDM Deployment Key

The scripts will download the *latest Banyan app* version and install it using a "Zero Touch" flow for the logged-on user. The scripts also allow you to (optionally) specify the exact app version to install.


## MacOS

Launch a terminal and run `banyan-macos.sh`.

```
sudo ./banyan-macos.sh <INVITE_CODE> <DEPLOY_KEY> <APP_VERSION (optional)>
```


## Windows

Launch PowerShell as Administrator and run `banyan-windows.ps1`

```
.\banyan-windows.ps1 <INVITE_CODE> <DEPLOY_KEY> <APP_VERSION (optional)>
```

