#!/bin/bash

nmcli device wifi list
nmcli device wifi show-password
nmcli --ask device wifi connect "$SSID"
