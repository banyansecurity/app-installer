#!/bin/bash

################################################################################
# Banyan App Installation for Linux
# Confirm or update the following variables prior to running the script

# Deployment Information
# Obtain from the Banyan admin console: Settings > App Deployment
INVITE_CODE="$1"
APP_VERSION="$2"

# Device Registration, Banyan App Configuration, and
# Device Certificate management should be handled by user

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
    sudo yum install -y curl
else
    sudo apt-get install -y curl
fi


if [[ -z "$APP_VERSION" ]]; then
    echo "Checking for latest version of app"
    loc=$( curl -sI https://www.banyanops.com/app/linux/v3/latest-deb | awk '/Location:/ {print $2}' )
    APP_VERSION=$( awk -F'banyanapp_|_amd64.deb' '{print $2}' <<< "$loc" )
fi

echo "Installing with invite code: $INVITE_CODE"
echo "Installing app version: $APP_VERSION"

logged_on_user=$( users | awk '{ print $1 }' )
echo "Installing app for user: $logged_on_user"

global_config_dir="/etc/banyanapp"
tmp_dir="/etc/banyanapp/tmp"
mkdir -p "$tmp_dir"

function download_install() {
    echo "Downloading installer DEB/RPM"

    if [[ $(command -v yum) ]]; then
        dl_path="banyanapp-${APP_VERSION}.x86_64.rpm"
    else
        dl_path="banyanapp_${APP_VERSION}_amd64.deb"
    fi
    dl_file="${tmp_dir}/${dl_path}"


    if [[ -f "${dl_file}" ]]; then
        echo "Installer DEB/RPM already downloaded"
    else
        curl -sL "https://www.banyanops.com/app/releases/${dl_path}" -o "${dl_file}"
    fi

    echo "Run installer"
    if [[ $(command -v yum) ]]; then
        sudo yum localinstall -y "${dl_file}"
    else
        sudo apt-get install -y "${dl_file}"
    fi
    sleep 5
}

echo "Running app install flow"
download_install
