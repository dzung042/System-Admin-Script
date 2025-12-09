#!/usr/bin/env bash
set -euo pipefail

POOL="${1:-}"   # optional pool name

# ---------- Helpers ----------
to_real_dev() {
  local d="$1"
  d="${d//[[:space:]]/}"

  # If ZFS prints bare by-id names (ata-..., wwn-...) without leading path
  if [[ "$d" != /* ]]; then
    if [[ -e "/dev/disk/by-id/$d" ]]; then
      d="/dev/disk/by-id/$d"
    else
      d="/dev/$d"
    fi
  fi

  readlink -f "$d" 2>/dev/null || echo "$d"
}

# /dev/sdX1 -> /dev/sdX ; /dev/nvme0n1p1 -> /dev/nvme0n1
to_parent_disk() {
  local real="$1"
  local pk
  pk="$(lsblk -no PKNAME "$real" 2>/dev/null || true)"
  if [[ -n "$pk" ]]; then
    echo "/dev/$pk"
  else
    echo "$real"
  fi
}

# /dev/sdX -> best by-id link if exists
to_byid() {
  local real="$1"
  if [[ -d /dev/disk/by-id ]]; then
    # pick first matching by-id symlink that resolves to real
    local link
    link="$(find /dev/disk/by-id -type l -exec readlink -f {} \; -printf '%p %l\n' 2>/dev/null \
           | awk -v r="$real" '$2==r{print $1; exit}')"
    if [[ -n "$link" ]]; then
      echo "$link"
      return
    fi
  fi
  echo "$real"
}

# Determine whether a token is by-id-ish
is_byid_token() {
  local t="$1"
  [[ "$t" =~ ^/dev/disk/by-(id|path)/ ]] && return 0
  [[ "$t" =~ ^(ata-|wwn-|scsi-|nvme-|virtio-) ]] && return 0
  return 1
}

# ---------- Collect vdev tokens from zpool status ----------
echo "==> Collecting ZFS vdev tokens..."
if [[ -n "$POOL" ]]; then
  STATUS_CMD=(zpool status -P "$POOL")
else
  STATUS_CMD=(zpool status -P)
fi

mapfile -t VDEV_TOKENS < <(
  "${STATUS_CMD[@]}" 2>/dev/null | awk '
    /config:/ {inconf=1; next}
    /errors:/ {inconf=0}
    inconf {
      dev=$1

      # skip logical labels / sizes / headings
      if (dev ~ /^(mirror|raidz|spare|logs|cache|special|dedup|replacing|rebuild|root)$/) next
      if (dev ~ /^(NAME|pool:|state:|scan:|config:|errors:|action:|see:|status:)$/) next
      if (dev ~ /:$/) next
      if (dev ~ /^[0-9]/) next
      if (dev ~ /^-+$/) next

      # accept device-like tokens only
      if (dev ~ /^\/dev\/disk\/by-(id|path)\// ||
          dev ~ /^\/dev\/sd[a-z]+[0-9]*$/ ||
          dev ~ /^\/dev\/nvme[0-9]+n[0-9]+p?[0-9]*$/ ||
          dev ~ /^\/dev\/vd[a-z]+[0-9]*$/ ||
          dev ~ /^\/dev\/xvd[a-z]+[0-9]*$/ ||
          dev ~ /^\/dev\/zd[0-9]+$/ ||
          dev ~ /^\/dev\/mapper\// ||
          dev ~ /^(ata-|wwn-|scsi-|nvme-|virtio-)/) {
        print dev
      }
    }'
)

if [[ "${#VDEV_TOKENS[@]}" -eq 0 ]]; then
  echo "No vdevs found. Are you root and ZFS installed?"
  exit 1
fi

echo "Raw vdev tokens:"
printf "  %s\n" "${VDEV_TOKENS[@]}"
echo

# ---------- Auto-detect mode ----------
BYID_COUNT=0
for t in "${VDEV_TOKENS[@]}"; do
  if is_byid_token "$t"; then
    ((BYID_COUNT++)) || true
  fi
done

MODE="name"
if (( BYID_COUNT * 2 >= ${#VDEV_TOKENS[@]} )); then
  MODE="byid"
fi

echo "==> Detected ZFS add mode: $MODE"
echo

# ---------- Build ZFS sets ----------
ZFS_REAL=()
ZFS_PARENT=()
ZFS_BYID=()

for t in "${VDEV_TOKENS[@]}"; do
  real="$(to_real_dev "$t")"
  parent="$(to_parent_disk "$real")"
  byid="$(to_byid "$parent")"

  ZFS_REAL+=("$real")
  ZFS_PARENT+=("$parent")
  ZFS_BYID+=("$byid")
done

mapfile -t ZFS_REAL    < <(printf "%s\n" "${ZFS_REAL[@]}"    | sort -u)
mapfile -t ZFS_PARENT  < <(printf "%s\n" "${ZFS_PARENT[@]}"  | sort -u)
mapfile -t ZFS_BYID    < <(printf "%s\n" "${ZFS_BYID[@]}"    | sort -u)

# ---------- Collect all server disks ----------
echo "==> Collecting all server disks..."
mapfile -t ALL_DISKS < <(
  lsblk -ndo NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}' | sort -u
)

echo "All server disks:"
printf "  %s\n" "${ALL_DISKS[@]}"
echo

# Build server by-id set (for byid mode compare)
SERVER_BYID=()
for d in "${ALL_DISKS[@]}"; do
  SERVER_BYID+=("$(to_byid "$d")")
done
mapfile -t SERVER_BYID < <(printf "%s\n" "${SERVER_BYID[@]}" | sort -u)

# ---------- Compare ----------
if [[ "$MODE" == "byid" ]]; then
  echo "==> Comparing by-id..."

  echo "Disks present in server but NOT in ZFS (by-id):"
  FOUND=0
  for id in "${SERVER_BYID[@]}"; do
    if ! printf "%s\n" "${ZFS_BYID[@]}" | grep -qx "$id"; then
      echo "  $id"
      FOUND=1
    fi
  done
  [[ "$FOUND" -eq 0 ]] && echo "  (none)"

  echo
  echo "ZFS vdevs whose by-id is NOT visible (missing/offline):"
  FOUND2=0
  for id in "${ZFS_BYID[@]}"; do
    if ! printf "%s\n" "${SERVER_BYID[@]}" | grep -qx "$id"; then
      echo "  $id"
      FOUND2=1
    fi
  done
  [[ "$FOUND2" -eq 0 ]] && echo "  (none)"

else
  echo "==> Comparing by parent disk names..."

  echo "Disks present in server but NOT in ZFS (parent /dev):"
  FOUND=0
  for d in "${ALL_DISKS[@]}"; do
    if ! printf "%s\n" "${ZFS_PARENT[@]}" | grep -qx "$d"; then
      echo "  $d"
      FOUND=1
    fi
  done
  [[ "$FOUND" -eq 0 ]] && echo "  (none)"

  echo
  echo "ZFS vdevs whose parent disk is NOT visible (missing/offline):"
  FOUND2=0
  for vd in "${ZFS_REAL[@]}"; do
    parent="$(to_parent_disk "$vd")"
    if ! printf "%s\n" "${ALL_DISKS[@]}" | grep -qx "$parent"; then
      echo "  vdev: $vd  (parent missing: $parent)"
      FOUND2=1
    fi
  done
  [[ "$FOUND2" -eq 0 ]] && echo "  (none)"
fi
