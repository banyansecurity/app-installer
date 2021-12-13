# Install Banyan App on Windows

## Install

```
./banyan-install.sh YOUR_DEPLOY_KEY
```

## Upgrade

```
./banyan-upgrade.sh NEW_APP _VERSION
```



---

1. Download PSTools from here https://download.sysinternals.com/files/PSTools.zip
2. Extract the PSTools.zip.zip file to C:\Windows\System32\
3. Open CMD.exe as Administrator
4. Enter this command
psexec -i -s cmd.exe -i
5. In the new CMD window enter this command
powershell
6. In this same window change the directory to the folder with all the install files
	6a. This folder should include:
		Banyan-Install.ps1
		mdm-config.json
7. Run this command once the directory is set to this folder
.\Banyan-Install.ps1