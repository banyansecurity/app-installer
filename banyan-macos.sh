#!/bin/bash
################################################################################
#Banyan Zero Touch Installation
#Please confirm or update the following variables prior to installing the script

#Deployment Information

INVITE_CODE="$1"
DEPLOYMENT_KEY="$2"
APP_VERSION="$3"

#Device Registration and Banyan App Configuration

DEVICE_OWNERSHIP="C"
CA_CERTS_PREINSTALLED= false
SKIP_CERT_SUPPRESSION= false
VENDOR_NAME="Jamf"
HIDE_SERVICES= false
DISABLE_QUIT= false
START_AT_BOOT= true
HIDE_ON_START= false

#User Information

USER_INFO_PATH=
USER_INFO_VARIABLE=
USER_INFO_EMAIL_VARIABLE=
MULTI_USER= false


################################################################################

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
    loc=$( curl -sI https://www.banyanops.com/app/macos/v3/latest | awk '/Location:/ {print $2}' )
    APP_VERSION=$( awk -F'Banyan-|.pkg' '{print $2}' <<< "$loc" )
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
    # assumes user and email are set in a custom plist file deployed via Device Manager
    # (you may instead use a different technique, like: https://github.com/pbowden-msft/SignInHelper)
    if [[ -e "/Library/Managed Preferences/userinfo.plist" ]]; then
        echo "userinfo.plist - extracting user email"
        MY_USER=$( defaults read "$USER_INFO_PATH" $USER_INFO_VARIABLE )
        MY_EMAIL=$( defaults read "$USER_INFO_PATH" $USER_INFO_EMAIL_VARIABLE )
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

    # the config below WILL install your org's Banyan Private Root CA
    # alternatively, you may use your Device Manager to push down the Private Root CA
    mdm_config_json='{
        "mdm_invite_code": "REPLACE_WITH_INVITE_CODE",
        "mdm_deploy_user": "REPLACE_WITH_USER",
        "mdm_deploy_email": "REPLACE_WITH_EMAIL",
        "mdm_device_ownership": "REPLACE_WITH_DEVICE_OWNERSHIP",
        "mdm_ca_certs_preinstalled": "REPLACE_WITH_CA_CERTS_PREINSTALLED",
        "mdm_skip_cert_suppression": "REPLACE_WITH_SKIP_CERT_SUPPRESSION",
        "mdm_vendor_name": "REPLACE_WITH_VENDOR_NAME",
        "mdm_hide_services": "REPLACE_WITH_HIDE_SERVICES",
        "mdm_disable_quit": "REPLACE_WITH_DISABLE_QUIT",
        "mdm_start_at_boot": "REPLACE_WITH_START_AT_BOOT",
        "mdm_hide_on_start": "REPLACE_WITHSTART_AT_BOOT"
    }'

    echo "$mdm_config_json" > "${global_config_file}"
    sed -i '' "s/REPLACE_WITH_INVITE_CODE/${INVITE_CODE}/" "${global_config_file}"
    sed -i '' "s/REPLACE_WITH_USER/${MY_USER}/" "${global_config_file}"
    sed -i '' "s/REPLACE_WITH_EMAIL/${MY_EMAIL}/" "${global_config_file}"
    sed -i '' "s/REPLACE_WITH_DEVICE_OWNERSHIP/${DEVICE_OWNERSHIP}/" "${global_config_file}"
    sed -i '' "s/REPLACE_WITH_CA_CERTS_PREINSTALLED/${CA_CERTS_PREINSTALLED}/" "${global_config_file}"
    sed -i '' "s/REPLACE_WITH_SKIP_CERT_SUPPRESSION/${SKIP_CERT_SUPPRESSION}/" "${global_config_file}"
    sed -i '' "s/REPLACE_WITH_VENDOR_NAME/${VENDOR_NAME}/" "${global_config_file}"
    sed -i '' "s/REPLACE_WITH_HIDE_SERVICES/${HIDE_SERVICES}/" "${global_config_file}"
    sed -i '' "s/REPLACE_WWITH_DISABLE_QUIT/${DISABLE_QUIT}/" "${global_config_file}"
    sed -i '' "s/REPLACE_WITH_START_AT_BOOT/${START_AT_BOOT}/" "${global_config_file}"
    sed -i '' "s/REPLACE_WITH_START_AT_BOOT/${HIDE_ON_START}/" "${global_config_file}"
}


function download_install() {
    echo "Downloading installer PKG"

    full_version="${APP_VERSION}"
    dl_file="${tmp_dir}/Banyan-${full_version}.pkg"

    if [[ -f "${dl_file}" ]]; then
        echo "Installer PKG already downloaded"
    else
        curl -sL "https://www.banyanops.com/app/releases/Banyan-${full_version}.pkg" -o "${dl_file}"
    fi

    echo "Run installer"
    sudo installer -pkg "${dl_file}" -target /
    sleep 3
}


function stage() {
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
