#!/bin/bash

set -e

APP_VERSION=$1
INVITE_CODE=$2
DEPLOY_KEY=$3

if [[ $USER != "root" ]]; then
	echo "This script must be run as root"
	exit 1
else
    console_user=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
	echo "Installing app for console user: $console_user"
fi

if [[ -z "$APP_VERSION" || -z "$INVITE_CODE" || -z "$DEPLOY_KEY" ]]; then
	echo "Usage: "
	echo "$0 <APP_VERSION> <INVITE_CODE> <DEPLOY_KEY>"
	exit 1
else
	echo "Installing app version: $APP_VERSION"
	echo "For org w invite code: $INVITE_CODE"
	echo "Using deploy key: $DEPLOY_KEY"
fi

etc_dir="/private/etc/banyanapp"
mdm_config_json='{
	"mdm_invite_code": "REPLACE_WITH_INVITE_CODE",
	"mdm_present": true,
	"mdm_vendor_name": JAMF,
	"mdm_start_at_boot": true,
	"mdm_hide_services": true,
	"mdm_hide_on_start": true	
}'
function create_dir () {
	mkdir -p "$etc_dir"
	echo "$mdm_config_json" > "${etc_dir}/mdm-config.json"
	sed -i '' "s/REPLACE_WITH_INVITE_CODE/${INVITE_CODE}/" "${etc_dir}/mdm-config.json"
}

tmp_dir="/tmp"
arm_suffix=""
function download_extract () {
	# check to see if the Mac is Intel or M1
	IFS='.' read osvers_major osvers_minor osvers_dot_version <<< "$(/usr/bin/sw_vers -productVersion)"
	if [[ ${osvers_major} -ge 11 ]]; then
	    processor=$(/usr/sbin/sysctl -n machdep.cpu.brand_string | grep -o "Intel")
	    if [[ -z "$processor" ]]; then
	    	arm_suffix="-arm-arm64"
	    fi
	fi

	curl -L "https://www.banyanops.com/app/releases/Banyan-${APP_VERSION}${arm_suffix}.dmg" -o "${tmp_dir}/Banyan.dmg"

	# Mount DMG
	hdiutil attach "${tmp_dir}/Banyan.dmg" -nobrowse

	# Copy Banyan.app to Applications
	ditto "/Volumes/Banyan ${APP_VERSION}${arm_suffix}/Banyan.app" "/Applications/Banyan.app"

	# Set ownership to console_user
	chown -R $console_user /Applications/Banyan.app
}

function stage () {
	# Setup Staged Deployment Key
	/Applications/Banyan.app/Contents/MacOS/Banyan --staged-deploy-key=$DEPLOY_KEY
}

function set_launch_agent () {
	# Create LaunchAgent
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
	chown $USER /Library/LaunchAgents/com.banyanapp.autoopen.plist
}

# Install and run staged install
create_dir
download_extract
stage
set_launch_agent

# Open Banyan as current user
su - "${console_user}" -c 'open /Applications/Banyan.app'

