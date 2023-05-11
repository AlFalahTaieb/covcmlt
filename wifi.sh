#!/bin/bash

green="\e[1;32m"
red="\e[1;31m"
undim="\e[0m"

echo "What would you like to do? Please select an option:"
echo "1. Display a list of detected WiFi networks"
echo "2. Display the password of the current WiFi network"
echo "3. Check if VPN is active and display geo-location information"
read choice

# Ask the user for inputs based on the selected choice
if [ "$choice" = "1" ]; then
  nmcli device wifi list
elif [ "$choice" = "2" ]; then
  nmcli device wifi show-password
elif [ "$choice" = "3" ]; then
  active=$(nmcli con show --active | grep -e mullvad -e tun0)
  if [ -z "$active" ]; then
    echo "VPN not active"
  else
    echo "VPN active"
  fi
  content=$(curl -sS "https://ipleak.net/json/")
  echo $content | jq -r '. | "IP: \(.ip) *** Country: \(.country_name) ** City: \(.city_name)  ** Timezone: \(.time_zone)"'
else
  echo "Invalid choice, please select between 1, 2 or 3."
  exit 1
fi