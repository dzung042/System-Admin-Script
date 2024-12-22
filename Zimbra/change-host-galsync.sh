#!/bin/bash
# This script will change zimbraMailHost on ldap
# run scipt with dry to see update changes
echo "setting ldap variables"
source ~/bin/zmshutil
zmsetvars
sleep 2

# check rundry
if [[ "$1" == "dry" ]]; then
    echo "dry run: Will not modify ldapmodify."
    dry_run=true
else
    dry_run=false
fi

# sethostname
read -p "Enter new zimbraMailHost: " input_hostname

if [[ -z "$input_hostname" ]]; then
    input_hostname=$(hostname)
    echo "Use hostname as zimbraMailHost: $input_hostname"
else
    echo "Use zimbraMailHost: $input_hostname"
fi

for i in `ldapsearch -x -H $ldap_master_url -D $zimbra_ldap_userdn -w $zimbra_ldap_password | grep uid=galsync| grep -vE "zimbraDataSourceName|dc=demo" |cut -d : -f 2 | sed 's/^\ //g'`
do

  echo "change zimbraMailHost for $i"

  if [[ "$dry_run" == false ]]; then
  ldapmodify -x -H $ldap_master_url -D $zimbra_ldap_userdn -w $zimbra_ldap_password << EOF
dn: $i
changetype: modify
replace: zimbraMailHost
zimbraMailHost: $input_hostname

EOF
  else
      echo "[Dry Run] Would modify zimbraMailHost for $i to $input_hostname"
  fi
done
