                    ____  _   _______ ________  ________________ __
                   / __ \/ | / / ___// ____/ / / / ____/ ____/ //_/
                  / / / /  |/ /\__ \/ /   / /_/ / __/ / /   / ,<
                 / /_/ / /|  /___/ / /___/ __  / /___/ /___/ /| |
                /_____/_/ |_//____/\____/_/ /_/_____/\____/_/ |_|


====================================

Shell Script to check DNS Expire date for a domain list.

Installation:
-------------
Use the curl or wget command to grab script as follows:

```
$ wget https://raw.githubusercontent.com/AlFalahTaieb/covcmlt/dns-check/master/dns-check.sh
## [ sample domain list for testing purpose ] ##
$ wget https://raw.githubusercontent.com/AlFalahTaieb/covcmlt/dns-check/master/domain-list.txt
## [ install it in /usr/local/bin dir ] ##
$ sudo cp -vf dns-check.sh /usr/local/bin/dns-check
$ sudo chmod +x /usr/local/bin/dns-check.sh
```

Usage:
------
Run it as follows:
```
$ dns-check -d google.com
$ dns-check -d kafteji.com
$ dns-check -f domain-list.txt
```
Sample outputs:
```
Domain                    Registrar                 Status   Expires     Days Left HTTP Status Cert Status Cert Valid  Cert D Left
------------------------- ------------------------- -------- ----------- --------- ----------- ----------- ----------- -----------
kafteji.com               IONOS SE                  Valid    04-mar-2024   299       OK        Expired     10-mai-2023 0
taieb.com                 NameCheap, Inc.           Valid    19-oct-2030   2719      OK        Valid       05-août-2023 87
cineart.com               DropCatch.com 136         Valid    05-mar-2025   665       OK        No cert
clubafricain.com          OVH sas                   Valid    08-mar-2024   303       OK        Valid       18-juil.-2023 69
cinefan.com               GoDaddy.com, LLC          Valid    10-aug-2024   458       OK        Valid       03-août-2023 84      21-dec-2018 189

```
[Setup Unix/Linux cron job](https://www.cyberciti.biz/faq/how-do-i-add-jobs-to-cron-under-linux-or-unix-oses/)  as follows to get email notification to send expiration notices:

```
@daily /path/to/dns-check.sh -f /path/to/your-domains.txt -e you@example.com
```
Getting help
------------
```
$ dns-check.sh -h
Usage: dns-check.sh [ -e email ] [ -x expir_days ] [ -q ] [ -a ] [ -h ]
          {[ -d domain_name ]} || { -f domain_file}

  -a               : Send a warning message through email
  -d domain        : Domain to analyze (interactive mode)
  -e email address : Email address to send expiration notices
  -f domain file   : File with a list of domains
  -h               : Print this screen
  -s whois server  : Whois sever to query for information
  -q               : Don't print anything on the console
  -x days          : Domain expiration interval (eg. if domain_date < days)
```

