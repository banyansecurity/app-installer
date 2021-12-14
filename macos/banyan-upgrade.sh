#!/bin/bash

APP_VERSION=$1

if [[ $USER != "root" ]]; then
    echo "This script must be run as root"
    exit 1
else
    console_user=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
    echo "Installing app for console user: $console_user"
fi

if [[ -z "$APP_VERSION" ]]; then
    echo "Usage: "
    echo "$0 <APP_VERSION>"
    exit 1
else
    echo "Upgrading to app version: $APP_VERSION"
fi

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

    # curl -L "https://www.banyanops.com/app/releases/Banyan-${APP_VERSION}${arm_suffix}.dmg" -o "${tmp_dir}/Banyan.dmg"

    # Mount DMG
    hdiutil attach "${tmp_dir}/Banyan.dmg" -nobrowse

    # Copy Banyan.app to Applications
    ditto "/Volumes/Banyan ${APP_VERSION}${arm_suffix}/Banyan.app" "/Applications/Banyan.app"

    # Set ownership to console_user
    chown -R $console_user /Applications/Banyan.app
}

# Stop current Banyan app
killall Banyan

# Extract new version
download_extract

# Open Banyan as current user
su - "${console_user}" -c 'open /Applications/Banyan.app'
