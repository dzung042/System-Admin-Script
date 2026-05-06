#!/bin/bash

echo "========================================"
echo "   CVE-2026 Interactive Security Tool"
echo "========================================"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

issues=0

log_safe()  { echo -e "${GREEN}[SAFE] $1${NC}"; }
log_warn()  { echo -e "${YELLOW}[CHECK] $1${NC}"; issues=$((issues+1)); }
log_vuln()  { echo -e "${RED}[VULNERABLE] $1${NC}"; issues=$((issues+1)); }

# =========================
# Apache check
# =========================

echo "---- Apache ----"

APACHE_FOUND=0

if command -v apache2 >/dev/null 2>&1; then
    VERSION=$(apache2 -v | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
    CONF_PATH="/etc/apache2"
    APACHE_FOUND=1
elif command -v httpd >/dev/null 2>&1; then
    VERSION=$(httpd -v | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
    CONF_PATH="/etc/httpd"
    APACHE_FOUND=1
fi

if [ $APACHE_FOUND -eq 1 ]; then
    echo "Version: $VERSION"

    if [[ "$VERSION" < "2.4.64" ]]; then
        log_vuln "Apache version outdated (CVE risk)"
    else
        log_safe "Apache version OK"
    fi

    MODULES=$(apachectl -M 2>/dev/null)

    echo "$MODULES" | grep -q http2 && log_warn "mod_http2 enabled (CVE-2026-24072)"
    echo "$MODULES" | grep -q lua   && log_warn "mod_lua enabled (CVE-2026-33006)"

    grep -Ri "SetHandler" $CONF_PATH >/dev/null 2>&1 && log_warn "SetHandler detected (CVE-2026-23918)"
else
    echo "Apache not found"
fi

# =========================
# Exim check
# =========================

echo ""
echo "---- Exim ----"

EXIM_FOUND=0

if command -v exim >/dev/null 2>&1; then
    EXIM_VERSION_FULL=$(exim -bV | head -n 1)
    EXIM_VERSION=$(echo "$EXIM_VERSION_FULL" | grep -oP '[0-9]+\.[0-9]+')
    EXIM_FOUND=1

    echo "Version: $EXIM_VERSION_FULL"

    if [[ "$EXIM_VERSION" < "4.97" ]]; then
        log_vuln "Exim outdated (CVE-2026-40685 risk)"
    else
        log_safe "Exim version OK"
    fi
else
    echo "Exim not installed"
fi

# =========================
# Summary
# =========================

echo ""
echo "========================================"
echo " SUMMARY"
echo "========================================"

if [ $issues -eq 0 ]; then
    log_safe "No issues detected"
    exit 0
else
    echo -e "${RED}Total issues: $issues${NC}"
fi

# =========================
# Ask for update
# =========================

echo ""
read -p "Do you want to auto-update vulnerable services? (y/n): " choice

if [[ "$choice" != "y" ]]; then
    echo "Skip update."
    exit 0
fi

# =========================
# Perform update
# =========================

echo ""
echo "Running update..."

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
echo "Restarting services..."

[ $APACHE_FOUND -eq 1 ] && systemctl restart apache2 2>/dev/null || systemctl restart httpd 2>/dev/null
[ $EXIM_FOUND -eq 1 ] && systemctl restart exim 2>/dev/null

echo ""
echo "========================================"
echo " UPDATE COMPLETED"
echo "========================================"
