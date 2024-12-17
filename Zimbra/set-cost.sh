#!/bin/bash

rm /tmp/modify-cos.zmp
echo "Retrieve zimbra user name..."

USERS=`su - zimbra -c 'zmprov -l gaa | sort'`;

for ACCOUNT in $USERS; do
echo "Modify COS for account $ACCOUNT"
echo "sac $ACCOUNT 5gb" >> /tmp/modify-cos.zmp
done

su - zimbra -c 'zmprov < /tmp/modify-cos.zmp'