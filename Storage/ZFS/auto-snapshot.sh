#!/bin/bash
# curl -O url /etc/cron.weekly/zfs-weekly-snapshot
# ===== CONFIG =====
DATASETS=(
  "Backup/1"
  "Backup/2"
)

KEEP=2
LABEL="weekly"

# Telegram (optional)
BOT_TOKEN=""
CHAT_ID=""

# ===== SYSTEM =====
HOST=$(hostname)
DATE=$(date +%Y-%m-%d-%H%M)
SNAP_NAME="zfs-auto-snap_${LABEL}-${DATE}"

LOG=""
ERROR=0

# ===== SNAPSHOT LOOP =====
for DS in "${DATASETS[@]}"; do
    if zfs list "$DS" >/dev/null 2>&1; then
        zfs snapshot "$DS@$SNAP_NAME" 2>>/tmp/zfs_snap_err.log
        if [ $? -eq 0 ]; then
            LOG+="✅ $DS snapshot OK\n"
        else
            LOG+="❌ $DS snapshot FAIL\n"
            ERROR=1
        fi
    else
        LOG+="⚠️ $DS not found\n"
        ERROR=1
    fi

    # ===== CLEAN OLD SNAP =====
    OLD_SNAPS=$(zfs list -t snapshot -o name -s creation | grep "$DS@zfs-auto-snap_${LABEL}" | head -n -$KEEP)

    for SNAP in $OLD_SNAPS; do
        zfs destroy "$SNAP" 2>/dev/null
    done
done

# ===== TELEGRAM (optional) =====
if [ ! -z "$BOT_TOKEN" ]; then
    if [ $ERROR -eq 0 ]; then
        STATUS="✅ SUCCESS"
    else
        STATUS="❌ ERROR"
    fi

    MESSAGE="ZFS Snapshot $STATUS
Host: $HOST
Time: $(date)

$LOG"

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="$MESSAGE" >/dev/null
fi

exit $ERROR
