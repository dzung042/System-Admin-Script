#!/bin/bash
# This is an offline updater for Bitdefender in Kerio Connect

rm -rf /tmp/bitdefender
mkdir -p /tmp/bitdefender/1
mkdir -p /root/backups

echo "Initialising update script"
cd /tmp/bitdefender || exit 1

if wget http://download.bitdefender.com/updates/update_av64bit/cumulative.zip; then
  unzip -u cumulative.zip -d /tmp/bitdefender/1/
  cp /tmp/bitdefender/1/bdcore.so.linux-x86_64 /tmp/bitdefender/1/bdcore.so
else
  echo "Download failed!"
  exit 1
fi

# Dung dich vu Kerio Connect
echo "Stopping Kerio Connect"
systemctl stop kerio-connect

echo "Updating..."
mv /opt/kerio/mailserver/bitdefender/1 /root/backups/$(date +%F)
mv /tmp/bitdefender/1 /opt/kerio/mailserver/bitdefender/

echo "Starting Kerio Connect"
systemctl start kerio-connect

echo "Checking status"
if systemctl is-active --quiet kerio-connect; then
  echo "Update successful"
else
  echo "Update failed"
fi