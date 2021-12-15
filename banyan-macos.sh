#!/bin/bash

INVITE_CODE=$1
DEPLOYMENT_KEY=$2
APP_VERSION=$3

if id -Gn $USER | grep -q -w -v admin; then
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

console_user=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
echo "Installing app for console user: $console_user"

global_config_dir="/private/etc/banyanapp"
tmp_dir="/tmp"


function create_config() {
	echo "Creating mdm-config json file"

	global_config_file="${global_config_dir}/mdm-config.json"

	mdm_config_json='{
		"mdm_invite_code": "REPLACE_WITH_INVITE_CODE",
		"mdm_deploy_user": "REPLACE_WITH_USER",
		"mdm_deploy_email": "REPLACE_WITH_EMAIL",
		"mdm_device_ownership": "C",
		"mdm_ca_certs_preinstalled": true,
		"mdm_skip_cert_suppression": true,
		"mdm_present": true,
		"mdm_vendor_name": "JAMF",
		"mdm_start_at_boot": true,
		"mdm_hide_on_start": true	
	}'

	mkdir -p "$global_config_dir"
	echo "$mdm_config_json" > "${global_config_file}"
	sed -i '' "s/REPLACE_WITH_INVITE_CODE/${INVITE_CODE}/" "${global_config_file}"
	sed -i '' "s/REPLACE_WITH_USER/${console_user}/" "${global_config_file}"
	sed -i '' "s/REPLACE_WITH_EMAIL/${console_user}@banyansecurity.io/" "${global_config_file}"
}


function download_extract() {
	echo "Downloading installer DMG"

	arm_suffix=""

	# check to see if the Mac is Intel or M1
	IFS='.' read osvers_major osvers_minor osvers_dot_version <<< "$(/usr/bin/sw_vers -productVersion)"
	if [[ ${osvers_major} -ge 11 ]]; then
	    processor=$(/usr/sbin/sysctl -n machdep.cpu.brand_string | grep -o "Intel")
	    if [[ -z "$processor" ]]; then
	    	echo "ARM proc"
	    	# TODO: ARM version doesn't work w ZT ... need to debug 
	    	# arm_suffix="-arm-arm64"
	    fi
	fi

	full_version="${APP_VERSION}${arm_suffix}"
	dl_file="${tmp_dir}/Banyan-${full_version}.dmg"

	if [[ -f "${dl_file}" ]]; then
		echo "Installer DMG already downloaded"
	else
		curl -sL "https://www.banyanops.com/app/releases/Banyan-${full_version}.dmg" -o "${dl_file}"
	fi

	# Mount DMG
	hdiutil attach "${dl_file}" -nobrowse

	# Copy Banyan.app to Applications
	ditto "/Volumes/Banyan ${full_version}/Banyan.app" "/Applications/Banyan.app"

	# Set ownership to console_user
	chown -R $console_user /Applications/Banyan.app

	# Unmount DMG
	hdiutil detach "/Volumes/Banyan ${full_version}"
}


function stage() {
	echo "Running staged deployment"
	/Applications/Banyan.app/Contents/MacOS/Banyan --staged-deploy-key=$DEPLOYMENT_KEY
	echo "Staged deployment done. Have the user start the Banyan app to complete registration."
}


function set_launch_agent() {
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


function start_app() {
	echo "Starting the Banyan app as console user"
	su - "${console_user}" -c 'open /Applications/Banyan.app'
	sleep 10
}


function stop_app() {
	echo "Stopping Banyan app"
	killall Banyan
}


create_config
download_extract
stage
set_launch_agent
start_app
