#!/bin/bash
set -euo pipefail
BKNS_API="https://my.bkns.net/api"

source /root/.secrets/dns.env

BASIC_TOKEN=$(printf "%s:%s" "$USERNAME" "$PASSWORD" | base64 -w0)

POST_DATA="{
    \"name\": \"_acme-challenge.${CERTBOT_DOMAIN}\",
    \"ttl\": 60,
    \"type\": \"TXT\",
    \"content\": \"${CERTBOT_VALIDATION}\"
}"

echo "$POST_DATA"

curl -v -X POST \
"${BKNS_API}/service/${SERVICE_ID}/dns/${ZONE_ID}/records" \
-H "Authorization: Basic ${BASIC_TOKEN}" \
-H "Content-Type: application/json" \
-d "${POST_DATA}"

sleep 30
