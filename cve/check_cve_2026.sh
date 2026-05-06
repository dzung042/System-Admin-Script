#!/bin/bash

echo "========================================"
echo " CVE-2026 Scanner (Apache + Exim)"
echo "========================================"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()    { echo -e "${GREEN}[SAFE] $1${NC}"; }
warn()  { echo -e "${YELLOW}[CHECK] $1${NC}"; }
vuln()  { echo -e "${RED}[VULNERABLE] $1${NC}"; }

# =========================
# APACHE CHECK
# =========================

echo "---- Apache Check ----"

if command -v apache2 >/dev/null 2>&1; then
    VERSION=$(apache2 -v | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
    CONF_PATH="/etc/apache2"
elif command -v httpd >/dev/null 2>&1; then
    VERSION=$(httpd -v | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
    CONF_PATH="/etc/httpd"
else
    echo "Apache not installed"
    APACHE=0
fi

if [ ! -z "$VERSION" ]; then
    echo "Apache version: $VERSION"

    if [[ "$VERSION" < "2.4.64" ]]; then
        warn "Apache có thể bị ảnh hưởng CVE-2026"
    else
        ok "Apache version mới"
    fi

    MODULES=$(apachectl -M 2>/dev/null)

    # CVE-2026-24072
    echo "Checking CVE-2026-24072 (HTTP2)..."
    echo "$MODULES" | grep -q http2 && warn "mod_http2 enabled" || ok "mod_http2 disabled"

    # CVE-2026-33006
    echo "Checking CVE-2026-33006 (mod_lua)..."
    echo "$MODULES" | grep -q lua && vuln "mod_lua enabled" || ok "mod_lua disabled"

    # CVE-2026-23918
    echo "Checking CVE-2026-23918 (handler/config)..."
    grep -Ri "SetHandler" $CONF_PATH 2>/dev/null && warn "SetHandler detected"
    grep -Ri "AddHandler" $CONF_PATH 2>/dev/null && warn "AddHandler detected"

fi

# =========================
# EXIM CHECK
# =========================

echo ""
echo "---- Exim Check ----"

if command -v exim >/dev/null 2>&1; then

    EXIM_VERSION=$(exim -bV | head -n 1)
    echo "Exim detected: $EXIM_VERSION"

    VERSION=$(echo "$EXIM_VERSION" | grep -oP '[0-9]+\.[0-9]+')

    # 👉 bạn cần update theo advisory chính thức
    if [[ "$VERSION" < "4.97" ]]; then
        vuln "Exim version cũ → có thể dính CVE-2026-40685"
    else
        ok "Exim version mới"
    fi

    echo "Checking config risk..."

    CONF_FILE="/etc/exim/exim.conf"
    [ -f "/etc/exim4/exim4.conf.template" ] && CONF_FILE="/etc/exim4/exim4.conf.template"

    # open relay check
    if grep -Ri "accept" $CONF_FILE 2>/dev/null | grep -q "0.0.0.0/0"; then
        vuln "Possible open relay detected"
    else
        ok "No open relay pattern"
    fi

else
    echo "Exim not installed"
fi

echo ""
echo "========================================"
echo " DONE"
echo "========================================"
