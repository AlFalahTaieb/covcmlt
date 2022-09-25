#!/bin/bash

# set column width
COLUMNS=2
# colors
green="\e[1;32m"
red="\e[1;31m"
undim="\e[0m"

mapfile -t containers < <(sudo docker ps -a --format '{{.Names}}\t{{.Status}}' | sort -k1 | awk '{ print $1,$2 }')

out=""
for i in "${!containers[@]}"; do
    IFS=" " read name status <<< ${containers[i]}
    if [[ "${status}" == "Up" ]]; then
        out+="${name}:,${green}${status,,}${undim},"
    else
        out+="${name}:,${red}${status,,}${undim},"
    fi
    if [ $((($i+1) % $COLUMNS)) -eq 0 ]; then
        out+="\n"
    fi
done
out+="\n"

printf "\ndocker status:\n"
printf "$out" | column -ts $',' | sed -e 's/^/  /'
