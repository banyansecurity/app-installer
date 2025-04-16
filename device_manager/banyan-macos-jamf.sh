#!/bin/bash

################################################################################
# Banyan Zero Touch Installation
# Confirm or update the following variables prior to running the script

# Deployment Information
# Obtain from the Banyan admin console: Settings > App Deployment
INVITE_CODE="$4"
DEPLOYMENT_KEY="$5"
APP_VERSION="$6"

# Device Registration and Banyan App Configuration
# Check docs for more options and details:
# https://docs.banyansecurity.io/docs/feature-guides/manage-users-and-devices/device-managers/distribute-desktopapp/#mdm-config-json
DEVICE_OWNERSHIP="C"
CA_CERTS_PREINSTALLED=false
SKIP_CERT_SUPPRESSION=false
IS_MANAGED_DEVICE=true
DEVICE_MANAGER_NAME="Jamf"
HIDE_SERVICES=false
DISABLE_QUIT=false
START_AT_BOOT=true
AUTO_LOGIN=false
HIDE_ON_START=true
DISABLE_AUTO_UPDATE=false

# User Information for Device Certificate
MULTI_USER=false
USERINFO_PATH="/Library/Managed Preferences/userinfo.plist"
USERINFO_USER_VAR="deploy_user"
USERINFO_EMAIL_VAR="deploy_email"

################################################################################


if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as the root user"
    exit 1
fi


if [[ -z "$INVITE_CODE" || -z "$DEPLOYMENT_KEY" ]]; then
    echo "Usage: "
    echo "$0 <INVITE_CODE> <DEPLOYMENT_KEY> <APP_VERSION (optional>"
    exit 1
fi

if [[ -z "$APP_VERSION" ]]; then
    echo "Checking for latest version of app"
    APP_VERSION=$( curl -s https://www.banyanops.com/app/releases/latest.yml | grep "version:" | awk '{print $2}' )
fi



echo "Installing with invite code: $INVITE_CODE"
echo "Installing using deploy key: *****"
echo "Installing app version: $APP_VERSION"

logged_on_user=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
echo "Installing app for user: $logged_on_user"

global_config_dir="/etc/banyanapp"
tmp_dir="/etc/banyanapp/tmp"
mkdir -p "$tmp_dir"


MY_USER=""
MY_EMAIL=""
function get_user_email() {
    if [[ "$MULTI_USER" != true ]]; then
        # for a single user device, assumes user and email are set in a custom plist file deployed via Device Manager
        # (you may instead use a different technique, like: https://github.com/pbowden-msft/SignInHelper)
        if [[ -e "$USERINFO_PATH" ]]; then
            echo "Extracting user email from: $USERINFO_PATH"
            MY_USER=$( defaults read "${USERINFO_PATH}" "${USERINFO_USER_VAR}" )
            MY_EMAIL=$( defaults read "${USERINFO_PATH}" "${USERINFO_EMAIL_VAR}" )
        fi
    fi

    echo "Installing for user with name: $MY_USER"
    echo "Installing for user with email: $MY_EMAIL"
    if [[ -z "$MY_EMAIL" ]]; then
        echo "No user specified - device certificate will be issued to the default **STAGED USER**"
    fi
}


function create_config() {
    echo "Creating mdm-config json file"
    global_config_file="${global_config_dir}/mdm-config.json"

    mdm_config_json='{
        "mdm_invite_code": '"\"${INVITE_CODE}\""',
        "mdm_deploy_user": '"\"${MY_USER}\""',
        "mdm_deploy_email": '"\"${MY_EMAIL}\""',
        "mdm_device_ownership": '"\"${DEVICE_OWNERSHIP}\""',
        "mdm_ca_certs_preinstalled": '"${CA_CERTS_PREINSTALLED}"',
        "mdm_skip_cert_suppression": '"${SKIP_CERT_SUPPRESSION}"',
        "mdm_present": '"\"${IS_MANAGED_DEVICE}\""',
        "mdm_vendor_name": '"\"${DEVICE_MANAGER_NAME}\""',
        "mdm_hide_services": '"${HIDE_SERVICES}"',
        "mdm_disable_quit": '"${DISABLE_QUIT}"',
        "mdm_start_at_boot": '"${START_AT_BOOT}"',
        "mdm_hide_on_start": '"${HIDE_ON_START}"',
        "mdm_disable_auto_update": '"${DISABLE_AUTO_UPDATE}"'
    }'

    echo "$mdm_config_json" > "${global_config_file}"
}


function download_install() {
    echo "Downloading installer PKG"

    # check to see if the Mac is Intel or ARM; if ARM use the native build
    arm_suffix=""
    IFS='.' read osvers_major osvers_minor osvers_dot_version <<< "$(/usr/bin/sw_vers -productVersion)"
    if [[ ${osvers_major} -ge 11 ]]; then
        processor=$(/usr/sbin/sysctl -n machdep.cpu.brand_string | grep -o "Intel")
        if [[ -z "$processor" ]]; then
            echo "Detected ARM processor"
            arm_suffix="-arm64"
        fi
    fi

    full_version="${APP_VERSION}${arm_suffix}"
    dl_file="${tmp_dir}/Banyan-${full_version}.pkg"

    curl -sL "https://www.banyanops.com/app/releases/Banyan-${full_version}.pkg" -o "${dl_file}"
    if [[ $? -ne 0 ]]; then
        echo "Failed to download installer PKG"
        exit 1
    fi

    echo "Run installer"
    sudo installer -pkg "${dl_file}" -target /
    sleep 3
}


function stage() {
    echo "Running staged deployment"
    /Applications/Banyan.app/Contents/Resources/bin/banyanapp-admin stage --key=$DEPLOYMENT_KEY
    [[ $? -ne 0 ]] && exit 1 # Exit if non-zero exit code
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


if [[ "$INVITE_CODE" = "upgrade" && "$DEPLOYMENT_KEY" = "upgrade" ]]; then
    echo "Running upgrade flow"
    stop_app
    download_install
    start_app
else
    echo "Running zero-touch install flow"
    stop_app
    get_user_email
    create_config
    download_install
    stage
    create_config
    start_app
fi
