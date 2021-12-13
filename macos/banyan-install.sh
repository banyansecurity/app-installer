############Update to your Key#############
DEPLOYMENT_KEY="INSERT_DEPLOYMENT_KEY"
VERSION="2.5.0"
############Update to your Key#############

###################JSON INFO################
DATA='{
	"mdm_invite_code": "INVITECODE",
	"mdm_present": true,
	"mdm_vendor_name": Jamf
}
'
###################JSON INFO################

# Create Directory
mkdir /private/etc/banyanapp

# Create the JSON File
echo "$DATA" > /private/etc/banyanapp/mdm-config.json

# Get Current User
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Check to see if the Mac is Intel or M1
OLDIFS=$IFS
IFS='.' read osvers_major osvers_minor osvers_dot_version <<< "$(/usr/bin/sw_vers -productVersion)"

if [[ ${osvers_major} -ge 11 ]]; then

    processor=$(/usr/sbin/sysctl -n machdep.cpu.brand_string | grep -o "Intel")

    if [[ -n "$processor" ]]; then
        # Download DMG
        curl -L https://www.banyanops.com/app/releases/Banyan-"$VERSION".dmg -o /tmp/Banyan.dmg
    else
        # Download DMG
      	curl -L https://www.banyanops.com/app/releases/Banyan-"$VERSION"-arm-arm64.dmg -o /tmp/Banyan.dmg
    fi
fi

# Mount DMG
hdiutil attach /tmp/Banyan.dmg -nobrowse

# Copy Banyan.app to Applications
ditto "/Volumes/Banyan "$VERSION"/Banyan.app" "/Applications/Banyan.app"

# Set ownership to current user
chown -R $currentUser /Applications/Banyan.app

# Setup Staged Deployment Key
/Applications/Banyan.app/Contents/MacOS/Banyan --staged-deploy-key=$DEPLOYMENT_KEY

# Create LaunchAgent
DATA2='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/munki:/Library/Apple/usr/bin:/usr/local/sbin</string>
	</dict>
	<key>Label</key>
	<string>com.banyanapp.autoopen</string>
	<key>ProcessType</key>
	<string>Interactive</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Applications/Banyan.app/Contents/MacOS/Banyan</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>'

echo "$DATA2" > /Library/LaunchAgents/com.banyanapp.autoopen.plist

# Set permissions
chown root /Library/LaunchAgents/com.banyanapp.autoopen.plist

exit 0
