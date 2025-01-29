# Banyan App Installer

Automate installation of Banyan App on end-user devices.

See [Banyan documentation](https://docs.banyansecurity.io/docs/feature-guides/manage-users-and-devices/device-managers/distribute-desktopapp/) for more details.

---

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

### Linux

Launch a terminal and run:

```bash
sudo ./banyan-linux.sh <INVITE_CODE> <DEPLOYMENT_KEY> <APP_VERSION (optional)>
```
NOTE: The Linux script doesn't currently support MDM supplied user Information.

---

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

### Linux

Launch a terminal and run:

```bash
sudo ./banyan-linux.sh upgrade <APP_VERSION (optional)>
```

---

## Notes for usage with Device Managers

We have pre-configured the main script to be run via Device Managers (such as VMware Workspace ONE, Jamf Pro, Kandji, Microsoft Intune, etc.).

### Jamf Pro

Use the [**banyan-macos-jamf.sh**](device_manager/banyan-macos-jamf.sh) script, following our [Jamf Pro - Zero Touch Installation doc](https://docs.banyansecurity.io/docs/feature-guides/manage-users-and-devices/device-managers/jamf-pro-zero-touch/).


### Kandji

Use the [**banyan-macos-kandji.sh**](device_manager/banyan-macos-kandji.sh) script, following our [Kandji- Zero Touch Installation doc](https://docs.banyansecurity.io/docs/feature-guides/manage-users-and-devices/device-managers/kandji-zero-touch/).


### Microsoft Intune

Use the [**banyan-windows-intune.ps1**](device_manager/banyan-windows-intune.ps1) script, following our [Intune - Zero Touch Installation doc](https://docs.banyansecurity.io/docs/feature-guides/manage-users-and-devices/device-managers/intune-zero-touch/).


### VMWare Workspace One UEM

Use our base scripts and customize as needed, following our [Workspace ONE UEM - Device Identity & Enhanced TrustScoring doc](https://docs.banyanops.com/docs/feature-guides/manage-users-and-devices/device-managers/workspace-one-cert-api/#wsone). You need to set a few additional parameters in the `mdm-config.json` file so Banyan’s TrustScoring engine can correlate data from devices running the Banyan Desktop App with the data in Workspace ONE UEM:

- `mdm_vendor_name` should be set to **Airwatch**
- `mdm_present` should be **true**
- `mdm_vendor_udid` should be the **DEVICE UDID**



