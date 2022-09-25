#!/bin/bash

# WILL LIST ALL THE DETECTED WIFI
nmcli device wifi list
# SHOW A QR OF THE CURRENT CONNEXION
nmcli device wifi show-password
#SHOW IF VPN IS ACTIVE OR NOT ON THE CURRENT SESSION
active=$(nmcli con show --active | grep -i mullvad)
if [ -z "$active" ]
    then echo "VPN Not Active"
else 
    echo "VPN Active"
fi
