#!/bin/bash

################################################################################
# Banyan Zero Touch Installation
# Confirm or update the following variables prior to running the script

# Deployment Information
# Obtain from the Banyan admin console: Settings > App Deployment
INVITE_CODE="$1"
APP_VERSION="$2"

# Device Registration and Banyan App Configuration
# Check docs for more options and details:
# https://docs.banyansecurity.io/docs/feature-guides/manage-users-and-devices/device-managers/distribute-desktopapp/#mdm-config-json
DEVICE_OWNERSHIP="S"
CA_CERTS_PREINSTALLED=false
SKIP_CERT_SUPPRESSION=false
VENDOR_NAME=""
HIDE_SERVICES=false
DISABLE_QUIT=false
START_AT_BOOT=true
HIDE_ON_START=true
DISABLE_AUTO_UPDATE=false

# Device Certificate management isn't supported on Linux





################################################################################


if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as the root user"
    exit 1
fi


if [[ -z "$INVITE_CODE" ]]; then
    echo "Usage: "
    echo "$0 <INVITE_CODE> <APP_VERSION (optional>"
    exit 1
fi

if [[ -z "$APP_VERSION" ]]; then
    echo "Checking for latest version of app"
    loc=$( curl -sI https://www.banyanops.com/app/linux/v3/latest-deb | awk '/Location:/ {print $2}' )
    APP_VERSION=$( awk -F'banyanapp_|_amd64.deb' '{print $2}' <<< "$loc" )
fi



echo "Installing with invite code: $INVITE_CODE"
echo "Installing using deploy key: *****"
echo "Installing app version: $APP_VERSION"

logged_on_user=$( users | awk '{ print $1 }' )
echo "Installing app for user: $logged_on_user"

global_config_dir="/etc/banyanapp"
tmp_dir="/etc/banyanapp/tmp"
mkdir -p "$tmp_dir"























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
        "mdm_vendor_name": '"\"${VENDOR_NAME}\""',
        "mdm_hide_services": '"${HIDE_SERVICES}"',
        "mdm_disable_quit": '"${DISABLE_QUIT}"',
        "mdm_start_at_boot": '"${START_AT_BOOT}"',
        "mdm_hide_on_start": '"${HIDE_ON_START}"',
        "mdm_disable_auto_update": '"${DISABLE_AUTO_UPDATE}"'
    }'

    echo "$mdm_config_json" > "${global_config_file}"
}


function download_install() {
    echo "Downloading installer DEB/RPM"

    if [[ $(command -v dpkg) ]]; then
        echo "Found dpkg; assume DEB"
        dl_path="banyanapp_${APP_VERSION}_amd64.deb"
    else
        echo "No dpkg; assume RPM"
        dl_path="banyanapp-${APP_VERSION}.x86_64.rpm"
    fi
    dl_file="${tmp_dir}/${dl_path}"


    if [[ -f "${dl_file}" ]]; then
        echo "Installer DEB/RPM already downloaded"
    else
        curl -sL "https://www.banyanops.com/app/releases/${dl_path}" -o "${dl_file}"
    fi

    echo "Run installer"
    if [[ $(command -v dpkg) ]]; then
        sudo dpkg -i "${dl_file}"
    else
        sudo rpm -i "${dl_file}"
    fi
    sleep 3
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


if [[ "$INVITE_CODE" = "upgrade" ]]; then
    echo "Running upgrade flow"
    stop_app
    download_install
    start_app
else
    echo "Running zero-touch install flow"
    stop_app
    create_config
    download_install
    create_config
    start_app
fi
