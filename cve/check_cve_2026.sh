#!/bin/bash

echo "========================================"
echo "   CONG CU KIEM TRA CVE-2026"
echo "========================================"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

issues=0
outdated=0

MODE="interactive"

# tham so
if [[ "$1" == "--auto" ]]; then
  MODE="auto"
elif [[ "$1" == "--scan" ]]; then
  MODE="scan"
fi

log_safe()  { echo -e "${GREEN}[AN TOAN] $1${NC}"; }
log_risk()  { echo -e "${YELLOW}[RUI RO] $1${NC}"; issues=$((issues+1)); }
log_old()   { echo -e "${BLUE}[CAN NANG CAP] $1${NC}"; issues=$((issues+1)); outdated=$((outdated+1)); }

# =========================
# Apache
# =========================

echo "---- Apache ----"

APACHE_FOUND=0

if command -v apache2 >/dev/null 2>&1; then
    VERSION=$(apache2 -v | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
    CONF_PATH="/etc/apache2"
    SERVICE_NAME="apache2"
    APACHE_FOUND=1
elif command -v httpd >/dev/null 2>&1; then
    VERSION=$(httpd -v | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
    CONF_PATH="/etc/httpd"
    SERVICE_NAME="httpd"
    APACHE_FOUND=1
fi

if [ $APACHE_FOUND -eq 1 ]; then
    echo "Phien ban: $VERSION"

    if [[ "$VERSION" < "2.4.64" ]]; then
        log_old "Apache da cu, nen nang cap"
    else
        log_safe "Apache OK"
    fi

    MODULES=$(apachectl -M 2>/dev/null)

    echo "$MODULES" | grep -q http2 && log_risk "Dang bat mod_http2 (can kiem tra)"
    echo "$MODULES" | grep -q lua   && log_risk "Dang bat mod_lua (can kiem tra)"

    grep -Ri "SetHandler" $CONF_PATH >/dev/null 2>&1 && log_risk "Phat hien SetHandler (can kiem tra)"
else
    echo "Khong tim thay Apache"
fi

# =========================
# Exim
# =========================

echo ""
echo "---- Exim ----"

EXIM_FOUND=0

if command -v exim >/dev/null 2>&1; then
    EXIM_VERSION_FULL=$(exim -bV | head -n 1)
    EXIM_VERSION=$(echo "$EXIM_VERSION_FULL" | grep -oP '[0-9]+\.[0-9]+')
    SERVICE_NAME_EXIM="exim"
    EXIM_FOUND=1

    echo "Phien ban: $EXIM_VERSION_FULL"

    if [[ "$EXIM_VERSION" < "4.97" ]]; then
        log_old "Exim qua cu, nen nang cap"
    else
        log_safe "Exim OK"
    fi
else
    echo "Khong tim thay Exim"
fi

# =========================
# Tong ket
# =========================

echo ""
echo "========================================"
echo " TONG KET"
echo "========================================"

echo "Tong so van de: $issues"
echo "So dich vu can nang cap: $outdated"

if [ $issues -eq 0 ]; then
    log_safe "He thong an toan"
    exit 0
fi

# =========================
# Hoi co update khong
# =========================

DO_UPDATE="no"

if [[ "$MODE" == "auto" ]]; then
    DO_UPDATE="yes"
elif [[ "$MODE" == "interactive" ]]; then
    if [ -t 0 ]; then
        echo ""
        read -p "Ban co muon nang cap cac dich vu cu khong? (y/n): " choice
        [[ "$choice" == "y" ]] && DO_UPDATE="yes"
    else
        echo "Dang chay non-interactive -> bo qua hoi"
    fi
fi

if [[ "$DO_UPDATE" != "yes" ]]; then
    echo "Bo qua nang cap."
    exit 0
fi

# =========================
# Update
# =========================

echo ""
echo "Dang nang cap..."

if command -v apt >/dev/null 2>&1; then
    apt update

    [ $APACHE_FOUND -eq 1 ] && apt install apache2 -y
    [ $EXIM_FOUND -eq 1 ] && apt install exim4 -y

elif command -v yum >/dev/null 2>&1; then
    yum makecache

    [ $APACHE_FOUND -eq 1 ] && yum update httpd -y
    [ $EXIM_FOUND -eq 1 ] && yum update exim -y
fi

echo ""
echo "Khoi dong lai dich vu..."

[ $APACHE_FOUND -eq 1 ] && systemctl restart $SERVICE_NAME
[ $EXIM_FOUND -eq 1 ] && systemctl restart $SERVICE_NAME_EXIM

echo ""
echo "========================================"
echo " DA NANG CAP XONG"
echo "========================================"
