# This is script run cerbot with DNS on BKNS
## Create folder for variable
```
mkdir -p /root/.secrets
wget -O /root/.secrets/dns.env https://raw.githubusercontent.com/dzung042/System-Admin-Script/refs/heads/master/dnsbkns/dns.env
chmod 600 /root/.secrets/dns.env
```
### Edit dns.env with your info
This info you can see when login to my.bkns.net then chose edit dns zone on browser url bar.
```
USERNAME=""   # Username login
PASSWORD=""   # Password
SERVICE_ID=""  # ID Service DNS
ZONE_ID=""      # ID Zone Domain
```
## Download hook for dns
```
wget -O /root/.secrets/certbot-auth.sh https://raw.githubusercontent.com/dzung042/System-Admin-Script/refs/heads/master/dnsbkns/certbot-auth.sh
chmod +x  /root/.secrets/certbot-auth.sh
```
## Run certbot
```
certbot certonly   --manual   --preferred-challenges dns   --manual-auth-hook /root/certbot-auth.sh   -d domain.com
```
For better security, it is strongly recommended to create a dedicated contact, API user, or sub-account with restricted permissions only for the required domain or DNS zone.

Do not use:

Global administrator accounts
Full-access DNS accounts
Shared root-level API credentials

The API account should only have permissions to access the specific domain required for ACME DNS validation
