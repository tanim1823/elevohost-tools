#!/bin/bash
#
# PHP Extension Installer for CloudPanel (Ubuntu)
# ---------------------------------------------------
# Usage: sudo bash install-php-extension.sh <php_version> <extension_name>
# Example: sudo bash install-php-extension.sh 8.2 gmp
# Example: sudo bash install-php-extension.sh 8.2 bcmath
# Example: sudo bash install-php-extension.sh 8.2 intl
#
# Works for standard apt-installable PHP extensions on CloudPanel/Ubuntu.
# NOT for CyberPanel/LiteSpeed (lsphp) servers.
#
# Author: Tanvir / ElevoHost
# ---------------------------------------------------

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---- Check root ----
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script as root (use sudo).${NC}"
    exit 1
fi

# ---- Check arguments ----
if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${YELLOW}Usage: sudo bash install-php-extension.sh <php_version> <extension_name>${NC}"
    echo "Example: sudo bash install-php-extension.sh 8.2 gmp"
    exit 1
fi

PHP_VERSION="$1"
EXT_NAME="$2"
PHP_BIN="php${PHP_VERSION}"
PACKAGE="php${PHP_VERSION}-${EXT_NAME}"

echo -e "${YELLOW}=== PHP Extension Installer ===${NC}"
echo "PHP version : $PHP_VERSION"
echo "Extension   : $EXT_NAME"
echo "Package     : $PACKAGE"
echo ""

# ---- Check if PHP version exists ----
if ! command -v "$PHP_BIN" &> /dev/null; then
    echo -e "${RED}Error: $PHP_BIN not found on this system.${NC}"
    echo "Available PHP versions:"
    ls /etc/php/ 2>/dev/null
    exit 1
fi

# ---- Check if already installed ----
if $PHP_BIN -m | grep -qi "^${EXT_NAME}$"; then
    echo -e "${GREEN}✅ Extension '${EXT_NAME}' is already installed for PHP ${PHP_VERSION}.${NC}"
    exit 0
fi

# ---- Update apt and install ----
echo "Updating package list..."
apt update -qq

echo "Installing $PACKAGE ..."
if ! apt install -y "$PACKAGE"; then
    echo -e "${RED}Error: Package '$PACKAGE' not found in apt repositories.${NC}"
    echo -e "${YELLOW}Tip: If this is a newer PHP version, you may need the Ondrej Sury PPA:${NC}"
    echo "  sudo add-apt-repository ppa:ondrej/php"
    echo "  sudo apt update"
    echo "  sudo apt install $PACKAGE"
    exit 1
fi

# ---- Restart PHP-FPM ----
FPM_SERVICE="php${PHP_VERSION}-fpm"
if systemctl list-units --type=service --all | grep -q "$FPM_SERVICE"; then
    echo "Restarting $FPM_SERVICE ..."
    systemctl restart "$FPM_SERVICE"
    echo -e "${GREEN}$FPM_SERVICE restarted successfully.${NC}"
else
    echo -e "${YELLOW}Warning: $FPM_SERVICE service not found. Skipping restart.${NC}"
fi

# ---- Verify ----
echo ""
echo -e "${YELLOW}=== Verification ===${NC}"
if $PHP_BIN -m | grep -qi "^${EXT_NAME}$"; then
    echo -e "${GREEN}✅ Extension '${EXT_NAME}' successfully installed and loaded for PHP ${PHP_VERSION}.${NC}"
else
    echo -e "${RED}⚠ Extension installed but not showing in 'php -m'. You may need to check the ini file manually.${NC}"
fi
