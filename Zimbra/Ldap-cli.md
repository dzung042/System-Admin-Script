## Get ldap password
```sh
zmlocalconfig -s | grep ldap_root_password  
```
## set variables for cli
```sh
su - zimbra
source ~/bin/zmshutil;
zmsetvars
## this command will set environment variables  ldap_master_url zimbra_ldap_userdn zimbra_ldap_password
# delete account
ldapdelete -r -x -H $ldap_master_url -D $zimbra_ldap_userdn -w $zimbra_ldap_password uid=galsync,ou=people,dc=testcreateabc,dc=com
# modifie account
ldapmodify -x -H $ldap_master_url -D $zimbra_ldap_userdn -w $zimbra_ldap_password
## after use command end ldif change example
dn: uid=admin,ou=people,dc=example,dc=com
changetype: modify
replace: mail
mail: admin@example.com
mail: postmaster@example.com
mail: root@example.com
## end with ctrl + D to submit change
# Flush cache account
zmprov flushCache account USER@DOMAIN.com
## search config
ldapsearch  -x -H $ldap_master_url -D $zimbra_ldap_userdn -w $zimbra_ldap_password -b "uid=galsync,ou=people,dc=testcreateabc,dc=com"
## create file ldiff to modify
cat <<EOF > /tmp/change.ldif
dn: uid=admin,ou=people,dc=example,dc=com
changetype: modify
replace: mail
mail: admin@example.com
mail: postmaster@example.com
mail: root@example.com
EOF
ldapmodify -x -H $ldap_master_url -D $zimbra_ldap_userdn -w $zimbra_ldap_password -W -f /tmp/change.ldif
# export ldap to ldif
/opt/zimbra/libexec/zmslapcat /tmp/backupzimbra
```
## example change zimbraMailHost
```sh
ldapmodify -c -H $ldap_master_url -D cn=config -w $zimbra_ldap_password
dn: uid=galsync,ou=people,dc=aqr,dc=com
changetype: modify
replace: zimbraMailHost
zimbraMailHost: smtp.demo.com
# ctrl + D
# check
ldapsearch -x -H $ldap_master_url -D "cn=config" -w $zimbra_ldap_password -b "uid=galsync,ou=people,dc=aqr,dc=com" | grep zimbraMailHost
```
## docs
https://wiki.zimbra.com/wiki/Zimbra-LDAP_Multival_Configuration
