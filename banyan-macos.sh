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
	APP_VERSION=$( awk -F'Banyan-|(.dmg|.pkg)' '{print $2}' <<< "$loc" )
fi

echo "Installing with invite code: $INVITE_CODE"
echo "Installing using deploy key: $DEPLOYMENT_KEY"
echo "Installing app version: $APP_VERSION"

logged_on_user=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
echo "Installing app for user: $logged_on_user"

global_config_dir="/etc/banyanapp"
tmp_dir="/etc/banyanapp/tmp"

mkdir -p "$tmp_dir"

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

	echo "$mdm_config_json" > "${global_config_file}"
	sed -i '' "s/REPLACE_WITH_INVITE_CODE/${INVITE_CODE}/" "${global_config_file}"
	sed -i '' "s/REPLACE_WITH_USER/${deploy_user}/" "${global_config_file}"
	sed -i '' "s/REPLACE_WITH_EMAIL/${deploy_email}/" "${global_config_file}"
}

function download_install_pkg() {
	echo "Downloading installer PKG"

	full_version="${APP_VERSION}"
	dl_file="${tmp_dir}/Banyan-${full_version}.pkg"

	if [[ -f "${dl_file}" ]]; then
		echo "Installer PKG already downloaded"
	else
		curl -sL "https://www.banyanops.com/app/releases/Banyan-${full_version}.pkg" -o "${dl_file}"
	fi

    #Install PKG
    sudo installer -pkg "${dl_file}" -target /
    sleep 3
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
	sleep 3
	echo "Staged deployment done. Have the user start the Banyan app to complete registration."
}

function stage_v2() {
	echo "Running staged deployment"
	/Applications/Banyan.app/Contents/Resources/bin/banyanapp-admin stage --key=$DEPLOYMENT_KEY
	sleep 3
	echo "Staged deployment done. Have the user start the Banyan app to complete registration."
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

MAJOR_VER=${APP_VERSION:0:1}

if [[ "$INVITE_CODE" = "upgrade" && "$DEPLOYMENT_KEY" = "upgrade" ]]; then
	echo "Running upgrade flow"
	stop_app
	if [[ $MAJOR_VER -eq 2 ]]; then
		download_install
	else
		download_install_pkg
	fi
	start_app
else
	echo "Running zero-touch install flow"
	create_config
	stop_app
	if [[ $MAJOR_VER -eq 2 ]]; then
		download_install
		stage
	else
		download_install_pkg
		stage_v2
	fi
	start_app
fi
