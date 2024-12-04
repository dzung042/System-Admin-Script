#!/bin/bash
ip_list=($(hostname -I))
#public_ip=$(curl -s https://ipinfo.io/ip)
apache_config="/etc/apache2/conf.d/includes/pre_virtualhost_2.conf"
for ip in "${ip_list[@]}"; do

echo "Add IP $ip to $apache_config"

cat << EOF >> "$apache_config"
# vhost IP $ip

<VirtualHost $ip:80>
ServerName $ip
DocumentRoot /var/www/html
</VirtualHost>

<VirtualHost $ip:443>
ServerName $ip
DocumentRoot /var/www/html
<IfModule suphp_module>
suPHP_UserGroup nobody nobody
</IfModule>
<Directory "/var/www/html">
AllowOverride All
</Directory>
<IfModule ssl_module>
SSLEngine on

SSLCertificateFile /var/cpanel/ssl/cpanel/cpanel.pem
SSLCertificateKeyFile /var/cpanel/ssl/cpanel/cpanel.pem
SSLCertificateChainFile /var/cpanel/ssl/cpanel/cpanel.pem
SSLUseStapling Off

</IfModule>
<IfModule security2_module>
SecRuleEngine On
</IfModule>
</VirtualHost>
EOF

done

echo "all config $apache_config done"
echo "Reload litespeed"
service lsws reload