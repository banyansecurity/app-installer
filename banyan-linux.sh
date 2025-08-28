#!/bin/bash

################################################################################
# Banyan App Installation for Linux
# Confirm or update the following variables prior to running the script

# Deployment Information
# Obtain from the Banyan admin console: Settings > App Deployment
INVITE_CODE="$1"
DEPLOYMENT_KEY="$2"
APP_VERSION="$3"

# Device Registration and Banyan App Configuration
# Check docs for more options and details:
# https://docs.banyansecurity.io/docs/feature-guides/manage-users-and-devices/device-managers/distribute-desktopapp/#mdm-config-json
DEVICE_OWNERSHIP="C"
CA_CERTS_PREINSTALLED=false
SKIP_CERT_SUPPRESSION=false
IS_MANAGED_DEVICE=false
DEVICE_MANAGER_NAME=""
HIDE_SERVICES=false
DISABLE_QUIT=false
START_AT_BOOT=false
AUTO_LOGIN=false
HIDE_ON_START=false
DISABLE_AUTO_UPDATE=false
ALLOW_MULTIORG=false

# Device Certificate will be installed when user registers device

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


echo "Ensure curl is present"
if [[ $(command -v yum) ]]; then
    sudo yum -q check-update
    sudo yum install -y curl
else
    sudo apt-get -qq update
    sudo apt-get install -y curl
fi


if [[ -z "$APP_VERSION" ]]; then
    echo "Checking for latest version of app"
    APP_VERSION=$( curl -s https://www.banyanops.com/app/releases/latest.yml | grep "version:" | awk '{print $2}' )
fi

echo "Installing with invite code: $INVITE_CODE"
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
        "mdm_device_ownership": '"\"${DEVICE_OWNERSHIP}\""',
        "mdm_ca_certs_preinstalled": '"${CA_CERTS_PREINSTALLED}"',
        "mdm_skip_cert_suppression": '"${SKIP_CERT_SUPPRESSION}"',
        "mdm_present": '"\"${IS_MANAGED_DEVICE}\""',
        "mdm_vendor_name": '"\"${DEVICE_MANAGER_NAME}\""',
        "mdm_hide_services": '"${HIDE_SERVICES}"',
        "mdm_disable_quit": '"${DISABLE_QUIT}"',
        "mdm_start_at_boot": '"${START_AT_BOOT}"',
        "mdm_auto_login": '"${AUTO_LOGIN}"',
        "mdm_hide_on_start": '"${HIDE_ON_START}"',
        "mdm_disable_auto_update": '"${DISABLE_AUTO_UPDATE}"',
        "mdm_multi_org": '"${ALLOW_MULTIORG}"'
    }'

    echo "$mdm_config_json" > "${global_config_file}"
}


function download_install() {
    echo "Downloading installer DEB/RPM"

    if [[ $(command -v yum) ]]; then
        dl_path="banyanapp-${APP_VERSION}.x86_64.rpm"
    else
        dl_path="banyanapp_${APP_VERSION}_amd64.deb"
    fi
    dl_file="${tmp_dir}/${dl_path}"


    curl -sL "https://www.banyanops.com/app/releases/${dl_path}" -o "${dl_file}"

    echo "Run installer"
    if [[ $(command -v yum) ]]; then
        sudo yum localinstall -y "${dl_file}"
    else
        sudo apt-get install -y "${dl_file}"
    fi
    sleep 5
}

function start_app() {
    echo "Starting the Banyan app as: $logged_on_user"
    #start app and disown from shell
    sudo sudo -u "$logged_on_user" nohup /opt/Banyan/banyanapp &>/dev/null & disown
    sleep 5
}

function stop_app() {
    echo "Stopping Banyan app"
    killall banyanapp
    sleep 2
}

function stage() {
      echo "Running staged deployment"
      /opt/Banyan/resources/bin/banyanapp-admin stage --key=$DEPLOYMENT_KEY
      [[ $? -ne 0 ]] && exit 1 # Exit if non-zero exit code
      sleep 3
      echo "Staged deployment done. Have the user start the Banyan app to complete registration."
}


if [[ "$INVITE_CODE" = "upgrade" ]]; then
    echo "Running upgrade flow"
    stop_app
    download_install
else
    echo "Running zero-touch install flow"
    stop_app
    create_config
    download_install
    stage
    create_config
    start_app
fi
