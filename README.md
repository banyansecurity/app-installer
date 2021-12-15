# Banyan App Installer

Automate installation of Banyan App on end-user devices.

## 1. Zero Touch Install Flow

In the Banyan Command Center, navigate to **Settings** > **App Deployment**. Note down your org-specific app deployment parameters for use in the scripts below:
- Invite Code
- Deployment Key

The script will:
1. Create an `mdm-config.json` file that specifies app functionality
2. Download the *latest Banyan app* version and install it (you can also optionally specify an exact app version)
3. Stage the app with the device certificate
4. Start the app as the logged-on user


### MacOS

Launch a terminal and run:

```
sudo ./banyan-macos.sh <INVITE_CODE> <DEPLOYMENT_KEY> <APP_VERSION (optional)>
```

### Windows

Launch PowerShell as Administrator and run:

```
.\banyan-windows.ps1 <INVITE_CODE> <DEPLOYMENT_KEY> <APP_VERSION (optional)>
```


## 2. Upgrade Flow

You can also use the scripts to upgrade the version of the Banyan app running on a device. Use the string `"upgrade"` for the Invite Code and Deployment Key parameters.

The script will:
1. Stop the app if it running
2. Download the *latest Banyan app* version and install it (you can also optionally specify an exact app version)
3. Start the app as the logged-on user


### MacOS

Launch a terminal and run:

```
sudo ./banyan-macos.sh upgrade upgrade <APP_VERSION (optional)>
```

### Windows

Launch PowerShell as Administrator and run:

```
.\banyan-windows.ps1 upgrade upgrade <APP_VERSION (optional)>
```