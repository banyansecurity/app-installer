# Banyan App Installer

Automate installation of Banyan App on end-user devices.

See [Banyan documentation](https://docs.banyansecurity.io/docs/feature-guides/manage-users-and-devices/device-managers/distribute-desktopapp/) for more details.


## Install using Zero Touch Flow

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

```bash
sudo ./banyan-macos.sh <INVITE_CODE> <DEPLOYMENT_KEY> <APP_VERSION (optional)>
```

### Windows

Launch PowerShell as Administrator and run:

```powershell
.\banyan-windows.ps1 <INVITE_CODE> <DEPLOYMENT_KEY> <APP_VERSION (optional)>
```


## Upgrade Flow

You can also use the scripts to upgrade the version of the Banyan app running on a device. Use the string `"upgrade"` for the Invite Code and Deployment Key parameters.

The script will:
1. Stop the app if it running
2. Download the *latest Banyan app* version and install it (you can also optionally specify an exact app version)
3. Start the app as the logged-on user


### MacOS

Launch a terminal and run:

```bash
sudo ./banyan-macos.sh upgrade upgrade <APP_VERSION (optional)>
```

### Windows

Launch PowerShell as Administrator and run:

```powershell
.\banyan-windows.ps1 upgrade upgrade <APP_VERSION (optional)>
```


## Notes for usage with Device Managers

You can modify these script to be run via Device Managers (such as VMware Workspace ONE, Jamf Pro, Microsoft Intune, etc.).

### Jamf Pro

If you use [Jamf to run the Bash script](https://docs.jamf.com/10.26.0/jamf-pro/administrator-guide/Scripts.html), note that the first 3 input parameters are reserved for Jamf internal use. Instead, you have to set the Invite Code, Deployment Key and App Version as Parameter 4, Parameter 5 and Parameter 6 respectively. Update the script accordingly: 

```bash
INVITE_CODE="$4"
DEPLOYMENT_KEY="$5"
APP_VERSION="$6" #optional
```

### Microsoft Intune

If you use [Intune to run the Powershell script](https://docs.microsoft.com/en-us/mem/intune/apps/intune-management-extension), note that Intune doesn't currently permit you to pass in input parameters. Instead, you have to hardcode the Invite Code, Deployment Key and App Version. Update the script accordingly:

```powershell
$INVITE_CODE=<YOUR_INVITE_CODE>
$DEPLOYMENT_KEY=<YOUR_DEPLOYMENT_KEY>
$APP_VERSION=<YOUR_APP_VERSION (optional)>
```

### VMWare Workspace One UEM

If you use [Workspace One UEM to distribute the Banyan Desktop App](https://docs.banyanops.com/docs/feature-guides/manage-users-and-devices/device-managers/workspace-one-cert-api/#wsone), you need to set a few additional parameters in the `mdm-config.json` file so Banyan’s TrustScoring engine can correlate data from devices running the Banyan Desktop App with the data in Workspace ONE UEM:

- `mdm_vendor_name` should be **Airwatch**
- `mdm_present` should be **true**
- `mdm_vendor_udid` should be the **DEVICE UDID**



