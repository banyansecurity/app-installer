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
function download_extract() {
    # check to see if the Mac is Intel or M1
    IFS='.' read osvers_major osvers_minor osvers_dot_version <<< "$(/usr/bin/sw_vers -productVersion)"
    if [[ ${osvers_major} -ge 11 ]]; then
        processor=$(/usr/sbin/sysctl -n machdep.cpu.brand_string | grep -o "Intel")
        if [[ -z "$processor" ]]; then
            echo "ARM proc"
            # TODO: ARM version doesn't work w ZT ... need to debug             
            #arm_suffix="-arm-arm64"
        fi
    fi
    full_version="${APP_VERSION}${arm_suffix}"

    if [[ -f "${tmp_dir}/Banyan-${full_version}.dmg" ]]; then
        echo "DMG already downloaded"
    else
        curl -sL "https://www.banyanops.com/app/releases/Banyan-${full_version}.dmg" -o "${tmp_dir}/Banyan-${full_version}.dmg"
    fi

    # Mount DMG
    hdiutil attach "${tmp_dir}/Banyan-${full_version}.dmg" -nobrowse

    # Copy Banyan.app to Applications
    ditto "/Volumes/Banyan ${full_version}/Banyan.app" "/Applications/Banyan.app"

    # Set ownership to console_user
    chown -R $console_user /Applications/Banyan.app

    # Unmount DMG
    hdiutil detach "/Volumes/Banyan ${full_version}"
}

function start() {
    echo "Starting the Banyan app as console user"
    su - "${console_user}" -c 'open /Applications/Banyan.app'
}

function stop () {
    echo "Stopping Banyan app"
    killall Banyan
}

stop
download_extract
launch
