#!/bin/bash
# This script will change zimbraCreateTimestamp  on ldap
echo "setting ldap variables"
source ~/bin/zmshutil
zmsetvars
sleep 2

for i in `ldapsearch -x -H $ldap_master_url -D $zimbra_ldap_userdn -w $zimbra_ldap_password | grep uid=| cut -d : -f 2 | sed 's/^\ //g'`
do

ldapmodify -x -H $ldap_master_url -D $zimbra_ldap_userdn -w $zimbra_ldap_password << EOF
dn: $i
changetype: modify
replace: zimbraCreateTimestamp
zimbraCreateTimestamp: 20140918100701Z

EOF

done
