#!/usr/bin/env bash

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/ssl/bin:/usr/sfw/bin
export PATH

# Who to page when an expired domain is detected (cmdline: -e)
ADMIN="dns@taieb.dev"
MAILFROM="dns@taieb.dev"
# Number of days in the warning threshhold  (cmdline: -x)
WARNDAYS=30

# If QUIET is set to TRUE, don't print anything on the console (cmdline: -q)
QUIET="FALSE"

# Don't send emails by default (cmdline: -a)
ALARM="FALSE"

# Whois server to use (cmdline: -s)
WHOIS_SERVER="whois.internic.org"

# Location of system binaries
AWK=$(which awk)
WHOIS=$(which whois)
DATE=$(which date)
CUT=$(which cut)
GREP=$(which grep)
SED=$(which sed)
OPENSSL=$(which openssl)
TR=$(which tr)
MAIL=$(which mail)
MKTEMP=$(which mktemp)
PRINTF=$(which printf)

# Place to stash temporary files
WHOIS_TMP="/var/tmp/whois.$$"
CERT_TMP=$($MKTEMP /var/tmp/cert.XXXXXX)
ERROR_TMP=$($MKTEMP /var/tmp/error.XXXXXX)

### Check to make sure the mktemp and printf utilities are available
if [ ! -f ${MKTEMP} ] || [ ! -f ${PRINTF} ]; then
    echo "ERROR: Unable to locate the mktemp or printf binary."
    echo "FIX: Please modify the \${MKTEMP} and \${PRINTF} variables in the program header."
    exit 1
fi

### Touch the files prior to using them
if [ ! -z "${CERT_TMP}" ] && [ ! -z "${ERROR_TMP}" ]; then
    touch ${CERT_TMP} ${ERROR_TMP}
else
    echo "ERROR: Problem creating temporary files"
    echo "FIX: Check that mktemp works on your system"
    exit 1
fi

date2julian() {
    if [ "${1} != "" ] && [ "${2} != "" ] && [ "${3}" != "" ]; then
        ## Since leap years add aday at the end of February,
        ## calculations are done from 1 March 0000 (a fictional year)
        d2j_tmpmonth=$((12 * ${3} + ${1} - 3))

        ## If it is not yet March, the year is changed to the previous year
        d2j_tmpyear=$((${d2j_tmpmonth} / 12))

        ## The number of days from 1 March 0000 is calculated
        ## and the number of days from 1 Jan. 4713BC is added
        echo $(((734 * ${d2j_tmpmonth} + 15) / 24 - 2 * ${d2j_tmpyear} + ${d2j_tmpyear} / 4 - \
        ${d2j_tmpyear} / 100 + ${d2j_tmpyear} / 400 + $2 + 1721119))
    else
        echo 0
    fi
}

#############################################################################
# Purpose: Convert a string month into an integer representation
# Arguments:
#   $1 -> Month name (e.g., Sep)
#############################################################################
getmonth() {
    LOWER=$(tolower $1)

    case ${LOWER} in
    jan) echo 1 ;;
    feb) echo 2 ;;
    mar) echo 3 ;;
    apr) echo 4 ;;
    may) echo 5 ;;
    jun) echo 6 ;;
    jul) echo 7 ;;
    aug) echo 8 ;;
    sep) echo 9 ;;
    oct) echo 10 ;;
    nov) echo 11 ;;
    dec) echo 12 ;;
    *) echo 0 ;;
    esac
}

#############################################################################
# Purpose: Calculate the number of seconds between two dates
# Arguments:
#   $1 -> Date #1
#   $2 -> Date #2
#############################################################################
date_diff() {
    if [ "${1}" != "" ] && [ "${2}" != "" ]; then
        echo $(expr ${2} - ${1})
    else
        echo 0
    fi
}

##################################################################
# Purpose: Converts a string to lower case
# Arguments:
#   $1 -> String to convert to lower case
##################################################################
tolower() {
    LOWER=$(echo ${1} | ${TR} [A-Z] [a-z])
    echo $LOWER
}

##################################################################
# Purpose: Access whois data to grab the registrar and expiration date
# Arguments:
#   $1 -> Domain to check
##################################################################
check_domain_status() {
    local REGISTRAR=""
    # Avoid WHOIS LIMIT EXCEEDED - slowdown our whois client by adding 3 sec
    sleep 1
    # Save the domain since set will trip up the ordering
    DOMAIN=${1}
    TLDTYPE="$(echo ${DOMAIN} | ${CUT} -d '.' -f3 | tr '[A-Z]' '[a-z]')"

    if [ "${TLDTYPE}" == "" ]; then
        TLDTYPE="$(echo ${DOMAIN} | ${CUT} -d '.' -f2 | tr '[A-Z]' '[a-z]')"
    fi

    # Invoke whois to find the domain registrar and expiration date
    #${WHOIS} -h ${WHOIS_SERVER} "=${1}" > ${WHOIS_TMP}
    # Let whois select server

    WHS="$(${WHOIS} -h "whois.iana.org" "${TLDTYPE}" | ${GREP} 'whois:' | ${AWK} '{print $2}')"

    if [ "${TLDTYPE}" == "jp" ]; then
        ${WHOIS} -h ${WHS} "${1}" >${WHOIS_TMP}
    elif [ "${TLDTYPE}" == "sk" ]; then
        ${WHOIS} -h ${WHS} "${1}" >${WHOIS_TMP}
    elif [ "${TLDTYPE}" == "se" ]; then
        ${WHOIS} -h ${WHS} "${1}" >${WHOIS_TMP}
    elif [ "${TLDTYPE}" == "br" ]; then
        ${WHOIS} -h ${WHS} "${1}" >${WHOIS_TMP}
    else
        ${WHOIS} -h ${WHOIS_SERVER} "=${1}" >${WHOIS_TMP}
    fi

    # Parse out the expiration date and registrar -- uses the last registrar it finds
    REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/Registrar:/ && $2 != ""  { REGISTRAR=substr($2,2,17) } END { print REGISTRAR }')

    if [ "${TLDTYPE}" == "uk" ]; then # for .uk domain
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/Registrar:/ && $0 != ""  { getline; REGISTRAR=substr($0,9,17) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "me" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/Registrar:/ && $2 != ""  { REGISTRAR=substr($2,2,23) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "jp" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} '/Registrant/ && $2 != ""  { REGISTRAR=substr($2,1,17) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "in" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/Sponsoring Registrar:/ && $2 != ""  { REGISTRAR=substr($2,1,47) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "md" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/Registrant:/ && $2 != ""  { REGISTRAR=substr($2,2,27) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "info" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/Registrar:/ && $2 != ""  { REGISTRAR=substr($2,2,17) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "ca" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/Registrar:/ && $0 != ""  { getline; REGISTRAR=substr($0,24,17) } END { print REGISTRAR }')
        if [ "${REGISTRAR}" = "" ]; then
            REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/Sponsoring Registrar:/ && $2 != "" { REGISTRAR=substr($2,1,17) } END { print REGISTRAR }')
        fi
    elif [ "${TLDTYPE}" == "edu" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/Registrant:/ && $0 != ""  { getline;REGISTRAR=substr($0,1,17) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "cafe" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/Registrar:/ && $0 != "" { REGISTRAR=substr($0,12,17) } END { print REGISTRAR }')

    elif [ "${TLDTYPE}" == "link" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/Registrar:/ && $0 != "" {  REGISTRAR=substr($0,12,17) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "blog" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/Registrar:/ && $0 != "" {  REGISTRAR=substr($0,12,17) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "ru" -o "${TLDTYPE}" == "su" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/registrar:/ && $2 != "" { REGISTRAR=substr($2,6,17) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "cz" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/registrar:/ && $2 != "" { REGISTRAR=substr($2,5,17) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "pl" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/REGISTRAR:/ && $0 != "" { getline; REGISTRAR=substr($0,0,35) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "xyz" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${GREP} Registrar: | ${AWK} -F: '/Registrar:/ && $0 != "" { getline; REGISTRAR=substr($0,12,35) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "se" -o "${TLDTYPE}" == "nu" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${AWK} -F: '/registrar:/ && $2 != "" { getline; REGISTRAR=substr($2,9,20) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "fi" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${GREP} 'registrar' | ${AWK} -F: '/registrar/ && $2 != "" { getline; REGISTRAR=substr($2,2,20) } END { print  REGISTRAR }')
    elif [ "${TLDTYPE}" == "fr" -o "${TLDTYPE}" == "re" -o "${TLDTYPE}" == "tf" -o "${TLDTYPE}" == "yt" -o "${TLDTYPE}" == "pm" -o "${TLDTYPE}" == "wf" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${GREP} "registrar:" | ${AWK} -F: '/registrar:/ && $2 != "" { getline; REGISTRAR=substr($2,4,20) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "dk" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${GREP} Copyright | ${AWK} '{print $8, $9, $10}')
    elif [ "${TLDTYPE}" == "tr" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${GREP} "Organization Name" -m 1 | ${AWK} -F: '{print $2}')
    elif [ "${TLDTYPE}" == "se" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${GREP} "holder:" -m 1 | ${AWK} -F' ' '{print $2}')
    elif [ "${TLDTYPE}" == "br" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${GREP} "owner:" -m 1 | ${AWK} -F: '/owner:/ && $2 != ""  { REGISTRAR=substr($2,8,25) } END { print REGISTRAR }')
    elif [ "${TLDTYPE}" == "sk" ]; then
        REGISTRAR=$(cat ${WHOIS_TMP} | ${GREP} "Name:" -m 1 | ${AWK} -F[:,] '{gsub(/^[ \t]+/,"",$2);  print $2}')
    fi

    # If the Registrar is NULL, then we didn't get any data
    if [ "${REGISTRAR}" = "" ]; then
        prints "$DOMAIN" "Unknown" "Unknown" "Unknown" "Unknown" "Unknown" "Unknown"
        return
    fi

    # The whois Expiration data should resemble the following: "Expiration Date: 09-may-2023"

    if [ "${TLDTYPE}" == "in" ]; then
        DOMAINDATE=$(cat ${WHOIS_TMP} | ${AWK} '/Expiration Date:/ { print $2 }' | ${CUT} -d ':' -f2)
    elif [ "${TLDTYPE}" == "info" -o "${TLDTYPE}" == "org" ]; then
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/Expiry Date:/ { print $4 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d'-' -f1)
        tmon=$(echo ${tdomdate} | ${CUT} -d'-' -f2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d'-' -f3 | ${CUT} -d'T' -f1)
        DOMAINDATE=$(echo $tday-$tmonth-$tyear)
    elif [ "${TLDTYPE}" == "md" ]; then # for .md domain
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/Expiration date:/ { print $3 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d'-' -f1)
        tmon=$(echo ${tdomdate} | ${CUT} -d'-' -f2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d'-' -f3)
        DOMAINDATE=$(echo $tday-$tmonth-$tyear)
    elif [ "${TLDTYPE}" == "uk" ]; then # for .uk domain
        DOMAINDATE=$(cat ${WHOIS_TMP} | ${AWK} '/Renewal date:/ || /Expiry date:/ { print $3 }')
    elif [ "${TLDTYPE}" == "jp" ]; then # for .jp 2010/04/30
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/Expires on/ { print $3 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d'/' -f1)
        tmon=$(echo ${tdomdate} | ${CUT} -d'/' -f2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d'/' -f3)
        DOMAINDATE=$(echo $tday-$tmonth-$tyear)
    elif [ "${TLDTYPE}" == "sk" ]; then # for .sk 2010/04/30
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/Valid Until/ { print $3 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d'-' -f1)
        tmon=$(echo ${tdomdate} | ${CUT} -d'-' -f2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d'-' -f3)
        DOMAINDATE=$(echo $tday-$tmonth-$tyear)
    elif [ "${TLDTYPE}" == "br" ]; then # for .sk 2010/04/30
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/expires/ { print $2 }')
        tyear=$(echo ${tdomdate} | ${AWK} '{ print substr($1,1,4)}')
        tmon=$(echo ${tdomdate} | ${AWK} '{print substr($1,5,2)}')
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${AWK} '{print substr($1,7,2)}')
        DOMAINDATE=$(echo $tday-$tmonth-$tyear)
    elif [ "${TLDTYPE}" == "ca" ]; then # for .ca 2010/04/30
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/Expiry date/ { print $3 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d'/' -f1)
        tmon=$(echo ${tdomdate} | ${CUT} -d'/' -f2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d'/' -f3)
        DOMAINDATE=$(echo $tday-$tmonth-$tyear)
    elif [ "${TLDTYPE}" == "me" ]; then # for .me domain
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/Registry Expiry Date:/ { print $4 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d "-" -f 1)
        tmon=$(echo ${tdomdate} | ${CUT} -d "-" -f 2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d "-" -f 3 | ${CUT} -d "T" -f 1)
        DOMAINDATE=$(echo "${tday}-${tmonth}-${tyear}")
    elif [ "${TLDTYPE}" == "ru" -o "${TLDTYPE}" == "su" ]; then # for .ru and .su 2014/11/13
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/paid-till:/ { print $2 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d'-' -f1)
        tmon=$(echo ${tdomdate} | ${CUT} -d'-' -f2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d "-" -f 3 | ${CUT} -d "T" -f 1)
        DOMAINDATE=$(echo "${tday}-${tmonth}-${tyear}")
    elif [ "${TLDTYPE}" == "com" -o "${TLDTYPE}" == "net" -o "${TLDTYPE}" == "org" -o "${TLDTYPE}" == "link" -o "${TLDTYPE}" == "blog" -o "${TLDTYPE}" == "cafe" -o "${TLDTYPE}" == "biz" -o "${TLDTYPE}" == "us" -o "${TLDTYPE}" == "mobi" -o "${TLDTYPE}" == "tv" -o "${TLDTYPE}" == "co" ]; then # added on 26-aug-2017 by nixCraft
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/Registry Expiry Date:/ { print $NF }')
        tyear=$(echo ${tdomdate} | ${CUT} -d'-' -f1)
        tmon=$(echo ${tdomdate} | ${CUT} -d'-' -f2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d "-" -f 3 | ${CUT} -d "T" -f 1)
        DOMAINDATE=$(echo "${tday}-${tmonth}-${tyear}")
    elif [ "${TLDTYPE}" == "edu" ]; then # added on 26-aug-2017 by nixCraft
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/Domain expires:/ { print $NF }')
        echo $tomdate
        tyear=$(echo ${tdomdate} | ${CUT} -d'-' -f3)
        tmon=$(echo ${tdomdate} | ${CUT} -d'-' -f2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d "-" -f 1)
        DOMAINDATE=$(echo "${tday}-${tmon}-${tyear}")

    elif [ "${TLDTYPE}" == "cz" ]; then # added on 20170830 by Minitram
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/expire:/ { print $NF }')
        echo $tomdate
        tyear=$(echo ${tdomdate} | ${CUT} -d'.' -f3)
        tmon=$(echo ${tdomdate} | ${CUT} -d'.' -f2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d "." -f 1)
        DOMAINDATE=$(echo "${tday}-${tmonth}-${tyear}")

    elif [ "${TLDTYPE}" == "pl" ]; then # NASK
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/renewal date:/ { print $3 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d'.' -f1)
        tmon=$(echo ${tdomdate} | ${CUT} -d'.' -f2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d'.' -f3)
        DOMAINDATE=$(echo "${tday}-${tmonth}-${tyear}")

    elif [ "${TLDTYPE}" == "xyz" ]; then
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/Registry Expiry Date:/ { print $4 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d "-" -f 1)
        tmon=$(echo ${tdomdate} | ${CUT} -d "-" -f 2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d "-" -f 3 | ${CUT} -d "T" -f 1)
        DOMAINDATE=$(echo "${tday}-${tmonth}-${tyear}")

    elif [ "${TLDTYPE}" == "se" -o "${TLDTYPE}" == "nu" ]; then
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/expires:/ { print $2 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d "-" -f 1)
        tmon=$(echo ${tdomdate} | ${CUT} -d "-" -f 2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d "-" -f 3 | ${CUT} -d "T" -f 1)
        DOMAINDATE=$(echo "${tday}-${tmonth}-${tyear}")

    elif [ "${TLDTYPE}" == "dk" ]; then
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/Expires:/ { print $2 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d "-" -f 1)
        tmon=$(echo ${tdomdate} | ${CUT} -d "-" -f 2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d "-" -f 3 | ${CUT} -d "T" -f 1)
        DOMAINDATE=$(echo "${tday}-${tmonth}-${tyear}")

    elif [ "${TLDTYPE}" == "fi" ]; then
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/expires/ { print $2 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d "." -f 3)
        tmon=$(echo ${tdomdate} | ${CUT} -d "." -f 2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d "." -f 1)
        DOMAINDATE=$(echo "${tday}-${tmonth}-${tyear}")

    elif [ "${TLDTYPE}" == "fr" -o "${TLDTYPE}" == "re" -o "${TLDTYPE}" == "tf" -o "${TLDTYPE}" == "yt" -o "${TLDTYPE}" == "pm" -o "${TLDTYPE}" == "wf" ]; then
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/Expiry Date:/ { print $3 }')
        tyear=$(echo ${tdomdate} | ${CUT} -d "/" -f 3)
        tmon=$(echo ${tdomdate} | ${CUT} -d "/" -f 2)
        case ${tmon} in
        1 | 01) tmonth=jan ;;
        2 | 02) tmonth=feb ;;
        3 | 03) tmonth=mar ;;
        4 | 04) tmonth=apr ;;
        5 | 05) tmonth=may ;;
        6 | 06) tmonth=jun ;;
        7 | 07) tmonth=jul ;;
        8 | 08) tmonth=aug ;;
        9 | 09) tmonth=sep ;;
        10) tmonth=oct ;;
        11) tmonth=nov ;;
        12) tmonth=dec ;;
        *) tmonth=0 ;;
        esac
        tday=$(echo ${tdomdate} | ${CUT} -d "/" -f 1)
        DOMAINDATE=$(echo "${tday}-${tmonth}-${tyear}")

    elif [ "${TLDTYPE}" == "tr" ]; then
        tdomdate=$(cat ${WHOIS_TMP} | ${AWK} '/Expires/ { print substr($3, 1, length($3)-1) }')
        tyear=$(echo ${tdomdate} | ${CUT} -d "-" -f 1)
        tmon=$(echo ${tdomdate} | ${CUT} -d "-" -f 2)
        tday=$(echo ${tdomdate} | ${CUT} -d "-" -f 3)
        DOMAINDATE=$(echo "${tday}-${tmon}-${tyear}")
    else
        DOMAINDATE=$(cat ${WHOIS_TMP} | ${AWK} '/Expiration/ { print $NF }')
    fi

    CERTIFICATE=$(echo | ${OPENSSL} s_client -servername ${DOMAIN} -connect ${DOMAIN}:443 2>/dev/null | ${OPENSSL} x509 -noout -checkend "$((3600 * 24 * ${WARNDAYS}))" 2>/dev/null)
    CERTDATE=$(echo | ${OPENSSL} s_client -servername ${DOMAIN} -connect ${DOMAIN}:443 2>/dev/null | ${OPENSSL} x509 -enddate -noout -inform pem 2>/dev/null | ${SED} 's/notAfter\=//')

    TODAY=$(date +%s)
    CERTEXP=$(date -d "${CERTDATE}" +%s)
    CERTVALID=$(date '+%d-%b-%Y' -d "${CERTDATE}")
    CERTDIFF="$(((${CERTEXP} - $TODAY) / (3600 * 24)))"

    if [ ${CERTDIFF} -le 0 ]; then
        echo "" | ${OPENSSL} s_client -servername ${DOMAIN} -connect ${DOMAIN}:443 2>${ERROR_TMP} 1>${CERT_TMP}

        if ${GREP} -i "Connection refused" ${ERROR_TMP} >/dev/null; then
            CERTSTATUS="No cert"
            CERTDIFF=""
            CERTVALID=""
        else
            if [ "${ALARM}" = "TRUE" ]; then
                echo "Certificate for domain ${DOMAIN} has expired!" |
                    ${MAIL} -s "Certificate for domain ${DOMAIN} has expired!" -a "From: ${MAILFROM}" ${ADMIN}
            fi
            CERTSTATUS="Expired"
        fi

    elif [ ${CERTDIFF} -lt ${WARNDAYS} ]; then
        if [ "${ALARM}" == "TRUE" ]; then
            echo "Certificate for domain ${DOMAIN} will expire on ${CERTDATE}" |
                ${MAIL} -s "Certificate for domain ${DOMAIN} will expire in ${CERTDIFF}-day(s)" -a "From: ${MAILFROM}" ${ADMIN}
        fi
        CERTSTATUS="Expiring"
    else
        CERTSTATUS="Valid"
    fi

    HTTPSTAT=$(curl -ILs qualityunit.com --max-redirs 5 | tac | grep -m1 HTTP/ | awk {'print $2'})
    if [ "${HTTPSTAT}" == "200" ]; then
        HTTPSTATUS="OK"
    else
        if [ "${ALARM}" == "TRUE" ]; then
            echo "HTTP status for domain ${DOMAIN} is ${HTTPSTAT}." |
                ${MAIL} -s "HTTP status for domain ${DOMAIN} is not correct!" -a "From: ${MAILFROM}" ${ADMIN}
        fi
        HTTPSTATUS="ERROR"
    fi

    #echo $DOMAINDATE # debug
    # Whois data should be in the following format: "13-feb-2006"
    IFS="-"
    set -- ${DOMAINDATE}
    MONTH=$(getmonth ${2})
    IFS=""

    # Convert the date to seconds, and get the diff between NOW and the expiration date
    DOMAINJULIAN=$(date2julian ${MONTH} ${1#0} ${3})
    DOMAINDIFF=$(date_diff ${NOWJULIAN} ${DOMAINJULIAN})

    if [ ${DOMAINDIFF} -lt 0 ]; then
        if [ "${ALARM}" == "TRUE" ]; then
            echo "The domain ${DOMAIN} has expired!" |
                ${MAIL} -s "Domain ${DOMAIN} has expired!" -a "From: ${MAILFROM}" ${ADMIN}
        fi

        prints "${DOMAIN}" "Expired" "${DOMAINDATE}" "${DOMAINDIFF}" "${REGISTRAR}" "${HTTPSTATUS}" "${CERTSTATUS}" "${CERTVALID}" "${CERTDIFF}"
    elif [ ${DOMAINDIFF} -lt ${WARNDAYS} ]; then
        if [ "${ALARM}" == "TRUE" ]; then
            echo "The domain ${DOMAIN} will expire on ${DOMAINDATE}" |
                ${MAIL} -s "Domain ${DOMAIN} will expire in ${DOMAINDIFF}-day(s)" -a "From: ${MAILFROM}" ${ADMIN}
        fi
        prints "${DOMAIN}" "Expiring" "${DOMAINDATE}" "${DOMAINDIFF}" "${REGISTRAR}" "${HTTPSTATUS}" "${CERTSTATUS}" "${CERTVALID}" "${CERTDIFF}"
    else
        prints "${DOMAIN}" "Valid" "${DOMAINDATE}" "${DOMAINDIFF}" "${REGISTRAR}" "${HTTPSTATUS}" "${CERTSTATUS}" "${CERTVALID}" "${CERTDIFF}"
    fi

}

print_heading() {
    if [ "${QUIET}" != "TRUE" ]; then
        printf "\n%-25s %-25s %-8s %-11s %-9s %-9s %-11s %-11s %-11s\n" "Domain" "Registrar" "Status" "Expires" "Days Left" "HTTP Status" "Cert Status" "Cert Valid" "Cert D Left"
        echo "------------------------- ------------------------- -------- ----------- --------- ----------- ----------- ----------- -----------"
    fi
}

#####################################################################
# Purpose: Print a line with the expiraton interval
# Arguments:
#   $1 -> Domain
#   $2 -> Status of domain (e.g., expired or valid)
#   $3 -> Date when domain will expire
#   $4 -> Days left until the domain will expire
#   $5 -> Domain registrar
#####################################################################
prints() {
    if [ "${QUIET}" != "TRUE" ]; then
        MIN_DATE=$(echo $3 | ${AWK} '{ print $1, $2, $4 }')
        printf "%-25s %-25s %-8s %-11s %-9s %-9s %-11s %-11s %-11s\n" "$1" "$5" "$2" "$MIN_DATE" "$4" "$6" "$7" "$8" "$9"
    fi
}

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -a           Send warning message through email
  -d domain    Analyze a specific domain (interactive mode)
  -e email     Email address to send expiration notices
  -f file      File with a list of domains
  -h           Print this help message
  -s server    Whois server to query for information
  -q           Quiet mode (no console output)
  -x days      Domain expiration interval (e.g., if domain_date < days)
EOF
}

### Evaluate the options passed on the command line
while getopts ae:f:hd:s:qx: option; do
    case "${option}" in
    a) ALARM="TRUE" ;;
    e) ADMIN=${OPTARG} ;;
    d) DOMAIN=${OPTARG} ;;
    f) SERVERFILE=$OPTARG ;;
    s) WHOIS_SERVER=$OPTARG ;;
    q) QUIET="TRUE" ;;
    x) WARNDAYS=$OPTARG ;;
    \?)
        usage
        exit 1
        ;;
    esac
done

### Check to see if the whois binary exists
if [ ! -f ${WHOIS} ]; then
    echo "ERROR: The whois binary does not exist in ${WHOIS} ."
    echo "  FIX: Please modify the \$WHOIS variable in the program header."
    exit 1
fi

### Check to make sure a date utility is available
if [ ! -f ${DATE} ]; then
    echo "ERROR: The date binary does not exist in ${DATE} ."
    echo "  FIX: Please modify the \$DATE variable in the program header."
    exit 1
fi

### Baseline the dates so we have something to compare to
MONTH=$(${DATE} "+%m")
DAY=$(${DATE} "+%d")
YEAR=$(${DATE} "+%Y")
NOWJULIAN=$(date2julian ${MONTH#0} ${DAY#0} ${YEAR})

### Touch the files prior to using them
touch ${WHOIS_TMP}

### If a HOST and PORT were passed on the cmdline, use those values
if [ "${DOMAIN}" != "" ]; then
    print_heading
    check_domain_status "${DOMAIN}"
### If a file and a "-a" are passed on the command line, check all
### of the domains in the file to see if they are about to expire
elif [ -f "${SERVERFILE}" ]; then
    print_heading
    while read DOMAIN; do
        check_domain_status "${DOMAIN}"

    done <${SERVERFILE}

### There was an error, so print a detailed usage message and exit
else
    usage
    exit 1
fi

# Add an extra newline
echo

### Remove the temporary files
rm -f ${WHOIS_TMP}

### Exit with a success indicator
exit 0
