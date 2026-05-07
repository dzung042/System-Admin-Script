#!/usr/bin/env bash
# Run with --run-dry to check and not apply change
set -e

RUN_DRY=0

if [[ "$1" == "--run-dry" ]]; then
    RUN_DRY=1
fi

echo "========================================="
echo "       ZFS ARC Auto Tuning Tool"
echo "========================================="
echo ""

# =========================================================
# Detect RAM
# =========================================================
TOTAL_RAM_BYTES=$(grep MemTotal /proc/meminfo | awk '{print $2 * 1024}')
TOTAL_RAM_GB=$((TOTAL_RAM_BYTES / 1024 / 1024 / 1024))

# =========================================================
# Detect ZFS pool size
# =========================================================
TOTAL_POOL_BYTES=$(zpool list -Hp -o size 2>/dev/null | awk '{sum+=$1} END {print sum}')

if [[ -z "$TOTAL_POOL_BYTES" || "$TOTAL_POOL_BYTES" == "0" ]]; then
    echo "[ERROR] No ZFS pool detected"
    exit 1
fi

TOTAL_POOL_TB=$((TOTAL_POOL_BYTES / 1024 / 1024 / 1024 / 1024))

# =========================================================
# Detect NVMe
# =========================================================
NVME_COUNT=$(ls /dev/nvme*n1 2>/dev/null | wc -l)

# =========================================================
# Detect VM workload
# =========================================================
if command -v qm >/dev/null 2>&1; then
    VM_COUNT=$(qm list 2>/dev/null | tail -n +2 | wc -l)
else
    VM_COUNT=0
fi

# =========================================================
# ARC Formula
# 4GB + 1GB per TB
# =========================================================
ARC_GB=$((4 + TOTAL_POOL_TB))

# =========================================================
# Adjust for NVMe
# =========================================================
if [[ "$NVME_COUNT" -gt 0 ]]; then
    ARC_GB=$((ARC_GB + 16))
fi

# =========================================================
# Adjust for VM Host
# =========================================================
if [[ "$VM_COUNT" -gt 20 ]]; then
    ARC_GB=$((ARC_GB + 32))
elif [[ "$VM_COUNT" -gt 5 ]]; then
    ARC_GB=$((ARC_GB + 16))
fi

# =========================================================
# Safety minimum
# =========================================================
if [[ "$ARC_GB" -lt 16 ]]; then
    ARC_GB=16
fi

# =========================================================
# Max ARC = 20% RAM
# =========================================================
MAX_ALLOWED=$((TOTAL_RAM_GB / 5))

if [[ "$ARC_GB" -gt "$MAX_ALLOWED" ]]; then
    ARC_GB=$MAX_ALLOWED
fi

ARC_BYTES=$((ARC_GB * 1024 * 1024 * 1024))
ARC_MIN_GB=$((ARC_GB / 4))
ARC_MIN_BYTES=$((ARC_MIN_GB * 1024 * 1024 * 1024))

# =========================================================
# Display detected info
# =========================================================
echo "Detected System:"
echo "-----------------------------------------"
echo "RAM                : ${TOTAL_RAM_GB} GB"
echo "ZFS Pool Size      : ${TOTAL_POOL_TB} TB"
echo "NVMe Devices       : ${NVME_COUNT}"
echo "VM Count           : ${VM_COUNT}"
echo ""

echo "Recommended ARC:"
echo "-----------------------------------------"
echo "ARC MAX            : ${ARC_GB} GB"
echo "ARC MIN            : ${ARC_MIN_GB} GB"
echo ""

# =========================================================
# Build config
# =========================================================
CONFIG=$(cat <<EOF
options zfs zfs_arc_max=${ARC_BYTES}
options zfs zfs_arc_min=${ARC_MIN_BYTES}

# VM/NVMe tuning
options zfs l2arc_noprefetch=1
options zfs zfs_prefetch_disable=1
options zfs zfs_txg_timeout=5
options zfs zfs_vdev_async_read_max_active=4
options zfs zfs_vdev_async_write_max_active=8
EOF
)

# =========================================================
# DRY RUN
# =========================================================
if [[ "$RUN_DRY" -eq 1 ]]; then
    echo "========================================="
    echo "             DRY RUN MODE"
    echo "========================================="
    echo ""

    echo "Generated config:"
    echo "-----------------------------------------"
    echo "$CONFIG"
    echo ""

else

    echo "$CONFIG" > /etc/modprobe.d/zfs.conf

    echo "[OK] Config written:"
    echo "/etc/modprobe.d/zfs.conf"
    echo ""

    echo "Apply changes:"
    echo "-----------------------------------------"
    echo "update-initramfs -u"
    echo "reboot"
    echo ""

fi

# =========================================================
# Optimization checks
# =========================================================
echo "========================================="
echo "       ZFS Optimization Check"
echo "========================================="
echo ""

POOL=$(zpool list -H -o name | head -n1)

if [[ -z "$POOL" ]]; then
    echo "[WARN] Unable to detect zpool"
    exit 0
fi

DATASET=$(zfs list -H -o name | head -n1)

# ---------------------------------------------------------
# compression
# ---------------------------------------------------------
COMP=$(zfs get -H -o value compression "$DATASET")

if [[ "$COMP" != "lz4" ]]; then
    echo "[WARN] compression=$COMP"
    echo "       Recommended:"
    echo "       zfs set compression=lz4 $DATASET"
    echo ""
else
    echo "[OK] compression=lz4"
fi

# ---------------------------------------------------------
# atime
# ---------------------------------------------------------
ATIME=$(zfs get -H -o value atime "$DATASET")

if [[ "$ATIME" != "off" ]]; then
    echo "[WARN] atime=$ATIME"
    echo "       Recommended:"
    echo "       zfs set atime=off $DATASET"
    echo ""
else
    echo "[OK] atime=off"
fi

# ---------------------------------------------------------
# xattr
# ---------------------------------------------------------
XATTR=$(zfs get -H -o value xattr "$DATASET")

if [[ "$XATTR" != "sa" ]]; then
    echo "[WARN] xattr=$XATTR"
    echo "       Recommended:"
    echo "       zfs set xattr=sa $DATASET"
    echo ""
else
    echo "[OK] xattr=sa"
fi

# ---------------------------------------------------------
# recordsize
# ---------------------------------------------------------
RECORDSIZE=$(zfs get -H -o value recordsize "$DATASET")

if [[ "$RECORDSIZE" != "16K" ]]; then
    echo "[WARN] recordsize=$RECORDSIZE"
    echo "       VM workload usually better with:"
    echo "       zfs set recordsize=16K $DATASET"
    echo ""
else
    echo "[OK] recordsize=16K"
fi

# ---------------------------------------------------------
# ashift
# ---------------------------------------------------------
ASHIFT=$(zpool get -H -o value ashift "$POOL")

if [[ "$ASHIFT" != "12" ]]; then
    echo "[WARN] ashift=$ASHIFT"
    echo "       NVMe/SSD recommended ashift=12"
    echo ""
else
    echo "[OK] ashift=12"
fi

# ---------------------------------------------------------
# L2ARC
# ---------------------------------------------------------
if zpool status | grep -qi cache; then
    echo "[INFO] L2ARC detected"

    CURRENT_NOPREFETCH=$(cat /sys/module/zfs/parameters/l2arc_noprefetch 2>/dev/null || echo "unknown")

    echo "       l2arc_noprefetch=$CURRENT_NOPREFETCH"

    if [[ "$CURRENT_NOPREFETCH" != "1" ]]; then
        echo "       Recommended for VM workload:"
        echo "       options zfs l2arc_noprefetch=1"
    fi

    echo ""
fi

# ---------------------------------------------------------
# ARC usage
# ---------------------------------------------------------
if command -v arcstat >/dev/null 2>&1; then
    echo "ARC Runtime:"
    echo "-----------------------------------------"
    arcstat 1 1 || true
    echo ""
fi

# ---------------------------------------------------------
# Final suggestions
# ---------------------------------------------------------
echo "========================================="
echo "            Recommendations"
echo "========================================="
echo ""

echo "- Use enterprise NVMe with PLP"
echo "- Prefer raw/zvol over qcow2"
echo "- Avoid sync=disabled on production"
echo "- Enable compression=lz4"
echo "- recordsize=16K recommended for VM"
echo "- Consider metadata special vdev"
echo "- ARC > 256GB usually not useful for VM hosts"
echo ""

echo "Done."
