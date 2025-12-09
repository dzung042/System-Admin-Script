#!/usr/bin/env bash
set -euo pipefail

# Ngưỡng cảnh báo (có thể chỉnh)
THRESH_REALLOC=1
THRESH_PENDING=1
THRESH_OFFLINE_UNC=1
THRESH_MEDIA_ERR=1
THRESH_CRC_ERR=10

# Lấy list disk vật lý
mapfile -t DISKS < <(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}')

if [[ ${#DISKS[@]} -eq 0 ]]; then
  echo "No disks found via lsblk."
  exit 1
fi

# Map /dev -> by-id cho dễ đọc
declare -A REAL2BYID=()
if [[ -d /dev/disk/by-id ]]; then
  while read -r link; do
    real="$(readlink -f "$link" 2>/dev/null || true)"
    [[ -n "$real" ]] && REAL2BYID["$real"]="$link"
  done < <(find /dev/disk/by-id -type l | sort)
fi

pretty_name() {
  local dev="$1"
  if [[ -n "${REAL2BYID[$dev]:-}" ]]; then
    echo "$dev (${REAL2BYID[$dev]})"
  else
    echo "$dev"
  fi
}

# Chạy smartctl theo loại disk
smart_run() {
  local dev="$1"

  # NVMe
  if [[ "$dev" =~ /dev/nvme ]]; then
    smartctl -a "$dev"
    return $?
  fi

  # SATA/SAS/USB disk thường
  smartctl -a "$dev"
  return $?
}

# Parse giá trị attribute (ATA/SCSI)
get_attr_raw() {
  local out="$1"
  local key="$2"
  echo "$out" | awk -v k="$key" '
    $0 ~ k {
      # cột RAW_VALUE thường là cột cuối
      print $NF
      exit
    }' | tr -dc '0-9'
}

# Parse NVMe critical warning / media errors / unsafe shutdowns
get_nvme_field() {
  local out="$1"
  local key="$2"
  echo "$out" | awk -v k="$key" '
    index($0,k){
      gsub(/[^0-9]/,"",$0);
      print $0; exit
    }'
}

echo "==> SMART check starting..."
echo

BAD_LIST=()
BAD_REASON=()

for dev in "${DISKS[@]}"; do
  echo "Checking: $(pretty_name "$dev")"

  # capture output + exit code
  OUT="$(smart_run "$dev" 2>/dev/null || true)"
  EC=${PIPESTATUS[0]:-0}

  REASONS=()

  # 1) Kiểm tra SMART overall-health nếu có
  if echo "$OUT" | grep -q "SMART overall-health self-assessment test result: FAILED"; then
    REASONS+=("SMART overall-health FAILED")
  fi
  if echo "$OUT" | grep -q "SMART Health Status:.*FAILED"; then
    REASONS+=("SMART Health Status FAILED")
  fi

  # 2) Kiểm tra smartctl exit code (bitmask)
  # bit 0 (1): command line error (ignore)
  # bit 1 (2): device open failed (treat as problem)
  # bit 2 (4): SMART command failed
  # bit 3 (8): SMART status = DISK FAILING
  # bit 4 (16): prefail attributes below threshold
  # bit 5 (32): errors logged
  # bit 6 (64): self-test errors
  if (( EC & 2 ));  then REASONS+=("device open failed"); fi
  if (( EC & 4 ));  then REASONS+=("SMART command failed"); fi
  if (( EC & 8 ));  then REASONS+=("SMART status says DISK FAILING"); fi
  if (( EC & 16 )); then REASONS+=("prefail attributes below threshold"); fi
  if (( EC & 32 )); then REASONS+=("errors logged"); fi
  if (( EC & 64 )); then REASONS+=("self-test errors"); fi

  # 3) ATA/SATA attributes quan trọng
  if echo "$OUT" | grep -q "ID#"; then
    realloc="$(get_attr_raw "$OUT" "Reallocated_Sector_Ct")"
    pending="$(get_attr_raw "$OUT" "Current_Pending_Sector")"
    offunc="$(get_attr_raw "$OUT" "Offline_Uncorrectable")"
    crcerr="$(get_attr_raw "$OUT" "UDMA_CRC_Error_Count")"

    realloc=${realloc:-0}
    pending=${pending:-0}
    offunc=${offunc:-0}
    crcerr=${crcerr:-0}

    if (( realloc >= THRESH_REALLOC )); then REASONS+=("Reallocated_Sector_Ct=$realloc"); fi
    if (( pending >= THRESH_PENDING )); then REASONS+=("Current_Pending_Sector=$pending"); fi
    if (( offunc >= THRESH_OFFLINE_UNC )); then REASONS+=("Offline_Uncorrectable=$offunc"); fi
    if (( crcerr >= THRESH_CRC_ERR )); then REASONS+=("UDMA_CRC_Error_Count=$crcerr"); fi
  fi

  # 4) SCSI/SAS fields (nếu có)
  if echo "$OUT" | grep -qi "Elements in grown defect list"; then
    grown="$(echo "$OUT" | awk -F: '/Elements in grown defect list/{gsub(/ /,"",$2); print $2}' | tr -dc '0-9')"
    grown=${grown:-0}
    if (( grown > 0 )); then REASONS+=("grown_defect_list=$grown"); fi
  fi

  # 5) NVMe fields
  if [[ "$dev" =~ /dev/nvme ]]; then
    crit="$(get_nvme_field "$OUT" "Critical Warning")"
    media="$(get_nvme_field "$OUT" "Media and Data Integrity Errors")"

    crit=${crit:-0}
    media=${media:-0}

    if (( crit > 0 )); then REASONS+=("NVMe Critical Warning=$crit"); fi
    if (( media >= THRESH_MEDIA_ERR )); then REASONS+=("NVMe Media/Data Errors=$media"); fi
  fi

  # Tổng hợp
  if [[ ${#REASONS[@]} -gt 0 ]]; then
    BAD_LIST+=("$dev")
    BAD_REASON+=("$(IFS='; '; echo "${REASONS[*]}")")
    echo "  -> BAD: ${REASONS[*]}"
  else
    echo "  -> OK"
  fi

  echo
done

echo "=============================="
echo "BAD / WARNING DISKS SUMMARY"
echo "=============================="

if [[ ${#BAD_LIST[@]} -eq 0 ]]; then
  echo "No bad disks detected."
  exit 0
fi

for i in "${!BAD_LIST[@]}"; do
  echo "- $(pretty_name "${BAD_LIST[$i]}")"
  echo "    Reason: ${BAD_REASON[$i]}"
done

exit 1
# smartctl -a /dev/sdx | egrep -i "grown defect|read|write|uncorrect|error"
