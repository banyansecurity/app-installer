#!/bin/bash

INVITE_CODE="$1"
DEPLOYMENT_KEY="$2"
APP_VERSION="$3"

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run with admin privilege"
	exit 1
fi

if [[ -z "$INVITE_CODE" || -z "$DEPLOYMENT_KEY" ]]; then
	echo "Usage: "
	echo "$0 <INVITE_CODE> <DEPLOYMENT_KEY> <APP_VERSION (optional>"
	exit 1
fi

if [[ -z "$APP_VERSION" ]]; then
	echo "Checking for latest version of app"
	loc=$( curl -sI https://www.banyanops.com/app/macos/latest | awk '/Location:/ {print $2}' )
	APP_VERSION=$( awk -F'Banyan-|.dmg' '{print $2}' <<< "$loc" )
fi

echo "Installing with invite code: $INVITE_CODE"
echo "Installing using deploy key: $DEPLOYMENT_KEY"
echo "Installing app version: $APP_VERSION"

logged_on_user=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
echo "Installing app for user: $logged_on_user"

global_config_dir="/private/etc/banyanapp"
tmp_dir="/tmp"


function create_config() {
	echo "Creating mdm-config json file"

	global_config_file="${global_config_dir}/mdm-config.json"

	deploy_user=""
	deploy_email=""

	# contact Banyan Support to enable the feature that will allow you to issue
	# a device certificate for a specific user instead of the default **STAGED USER**
	#
    # you can get user and email via a custom plist file deployed via Device Manager
	# or try one of these techniques: https://github.com/pbowden-msft/SignInHelper
	#if [[ -e "/Library/Managed Preferences/custom.plist" ]]; then
	#	deploy_user=$( defaults read "/Library/Managed Preferences/custom.plist" name )
	#	deploy_email=$( defaults read "/Library/Managed Preferences/custom.plist" email )
	#fi

	# the config below WILL NOT install your org's Banyan Private Root CA
	# on MacOS, we recommend using your Device Manager to push down the Private Root CA

	mdm_config_json='{
		"mdm_invite_code": "REPLACE_WITH_INVITE_CODE",
		"mdm_deploy_user": "REPLACE_WITH_USER",
		"mdm_deploy_email": "REPLACE_WITH_EMAIL",
		"mdm_device_ownership": "C",
		"mdm_ca_certs_preinstalled": true,
		"mdm_skip_cert_suppression": false,
		"mdm_vendor_name": "JAMF",
		"mdm_start_at_boot": true,
		"mdm_hide_on_start": true
	}'

	mkdir -p "$global_config_dir"
	echo "$mdm_config_json" > "${global_config_file}"
	sed -i '' "s/REPLACE_WITH_INVITE_CODE/${INVITE_CODE}/" "${global_config_file}"
	sed -i '' "s/REPLACE_WITH_USER/${deploy_user}/" "${global_config_file}"
	sed -i '' "s/REPLACE_WITH_EMAIL/${deploy_email}/" "${global_config_file}"
}


function download_install() {
	echo "Downloading installer DMG"

	arm_suffix=""

	# check to see if the Mac is Intel or M1
	IFS='.' read osvers_major osvers_minor osvers_dot_version <<< "$(/usr/bin/sw_vers -productVersion)"
	if [[ ${osvers_major} -ge 11 ]]; then
	    processor=$(/usr/sbin/sysctl -n machdep.cpu.brand_string | grep -o "Intel")
	    if [[ -z "$processor" ]]; then
	    	echo "Detected ARM processor"
	    	arm_suffix="-arm-arm64"
	    fi
	fi

	full_version="${APP_VERSION}${arm_suffix}"
	dl_file="${tmp_dir}/Banyan-${full_version}.dmg"

	if [[ -f "${dl_file}" ]]; then
		echo "Installer DMG already downloaded"
	else
		curl -sL "https://www.banyanops.com/app/releases/Banyan-${full_version}.dmg" -o "${dl_file}"
	fi

	# mount DMG
	hdiutil attach "${dl_file}" -nobrowse

	# copy Banyan.app to Applications
	ditto "/Volumes/Banyan ${full_version}/Banyan.app" "/Applications/Banyan.app"

	# set ownership to logged_on_user
	chown -R $logged_on_user /Applications/Banyan.app

	# unmount DMG
	hdiutil detach "/Volumes/Banyan ${full_version}"
}


function stage() {
	echo "Running staged deployment"
	/Applications/Banyan.app/Contents/MacOS/Banyan --staged-deploy-key=$DEPLOYMENT_KEY
	echo "Staged deployment done. Have the user start the Banyan app to complete registration."
}


function create_launch_agent() {
	echo "Creating LaunchAgent, so app launches upon user login"
	launch_xml='<?xml version="1.0" encoding="UTF-8"?>
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

	echo "$launch_xml" > /Library/LaunchAgents/com.banyanapp.autoopen.plist
	chown root /Library/LaunchAgents/com.banyanapp.autoopen.plist
}


function delete_launch_agent() {
	echo "Deleting LaunchAgent"
	rm -f /Library/LaunchAgents/com.banyanapp.autoopen.plist
}


function start_app() {
	echo "Starting the Banyan app as: $logged_on_user"
	sudo -H -u "${logged_on_user}" open /Applications/Banyan.app
	sleep 5
}


function stop_app() {
	echo "Stopping Banyan app"
	killall Banyan
	sleep 2
}


if [[ "$INVITE_CODE" = "upgrade" && "$DEPLOYMENT_KEY" = "upgrade" ]]; then
	echo "Running upgrade flow"
	stop_app
	download_install
	start_app
else
	echo "Running zero-touch install flow"
	create_config
	download_install
	stage
	start_app
fi
