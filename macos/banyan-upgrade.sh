#!/bin/bash
# Created by Kyle Ericson
# Version 1.0

############Update to your Version String#############
VERSION="2.5.0"
############Update to your Version String#############

# Get Current User
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Kill Banyan
killall Banyan

# Check to see if the Mac is Intel or M1
OLDIFS=$IFS
IFS='.' read osvers_major osvers_minor osvers_dot_version <<< "$(/usr/bin/sw_vers -productVersion)"

if [[ ${osvers_major} -ge 11 ]]; then

processor=$(/usr/sbin/sysctl -n machdep.cpu.brand_string | grep -o "Intel")

  if [[ -n "$processor" ]];
  then
        # Download DMG
        curl -L https://www.banyanops.com/app/releases/Banyan-"$VERSION".dmg -o /tmp/Banyan.dmg

  else
        # Download DMG
  	curl -L https://www.banyanops.com/app/releases/Banyan-"$VERSION"-arm-arm64.dmg -o /tmp/Banyan.dmg
fi
fi
# Mount DMG
hdiutil attach /tmp/Banyan.dmg -nobrowse

# Copy Banyan.app to Applications
ditto "/Volumes/Banyan "$VERSION"/Banyan.app" "/Applications/Banyan.app"

# Set ownership to current user
chown -R $currentUser /Applications/Banyan.app

# Open Banyan as current user
su - "${currentUser}" -c 'open /Applications/Banyan.app'

exit 0