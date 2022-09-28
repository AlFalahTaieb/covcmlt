#!/bin/bash
green="\e[1;32m"
red="\e[1;31m"
undim="\e[0m"

# WILL LIST ALL THE DETECTED WIFI
nmcli device wifi list
# SHOW A QR OF THE CURRENT CONNEXION
nmcli device wifi show-password
#SHOW IF VPN IS ACTIVE OR NOT ON THE CURRENT SESSION
active=$(nmcli con show --active | grep -e mullvad -e tun0)
if [ -z "$active" ]
    then echo "VPN Not Active"
    content=$(curl -sS "https://ipleak.net/json/")
    echo $content | jq -r '. | "IP: \(.ip) *** Country: \(.country_name) ** City: \(.city_name)  ** TIMEZONE: \(.time_zone)"'
else 
    echo "VPN Active"
    content=$(curl -sS "https://ipleak.net/json/")
    echo $content | jq -r '. | "IP: \(.ip) *** Country: \(.country_name) ** City: \(.city_name)  ** TIMEZONE: \(.time_zone)"'
fi


