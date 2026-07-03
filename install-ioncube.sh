#!/bin/bash
#
# ionCube Loader Installer for CloudPanel (Ubuntu)
# ---------------------------------------------------
# Usage: sudo bash install-ioncube.sh <php_version>
# Example: sudo bash install-ioncube.sh 8.2
#
# Supports PHP versions typically available on CloudPanel:
# 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5
#
# Author: Tanvir / ElevoHost
# ---------------------------------------------------

set -e

# ---- Colors for output ----
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ---- Check root ----
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script as root (use sudo).${NC}"
    exit 1
fi

# ---- Check PHP version argument ----
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: sudo bash install-ioncube.sh <php_version>${NC}"
    echo "Example: sudo bash install-ioncube.sh 8.2"
    exit 1
fi

PHP_VERSION="$1"
PHP_BIN="php${PHP_VERSION}"

echo -e "${YELLOW}=== ionCube Loader Installer ===${NC}"
echo "Target PHP version: $PHP_VERSION"

# ---- Check if PHP version exists on this server ----
if ! command -v "$PHP_BIN" &> /dev/null; then
    echo -e "${RED}Error: $PHP_BIN not found on this system.${NC}"
    echo "Available PHP versions:"
    ls /etc/php/ 2>/dev/null
    exit 1
fi

# ---- Get extension directory for this PHP version ----
EXT_DIR=$($PHP_BIN -i | grep "^extension_dir" | awk -F'=> ' '{print $2}' | head -n1 | xargs)

if [ -z "$EXT_DIR" ] || [ ! -d "$EXT_DIR" ]; then
    echo -e "${RED}Error: Could not detect extension directory for $PHP_BIN.${NC}"
    exit 1
fi

echo "Detected extension directory: $EXT_DIR"

# ---- Download ionCube if not already downloaded ----
WORKDIR="/tmp/ioncube_install"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [ ! -f "ioncube/ioncube_loader_lin_${PHP_VERSION}.so" ]; then
    echo "Downloading ionCube Loader package..."
    wget -q https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz -O ioncube_loaders.tar.gz
    tar xzf ioncube_loaders.tar.gz
fi

LOADER_FILE="ioncube/ioncube_loader_lin_${PHP_VERSION}.so"

if [ ! -f "$LOADER_FILE" ]; then
    echo -e "${RED}Error: No ionCube loader found for PHP $PHP_VERSION.${NC}"
    echo "ionCube may not support this PHP version yet. Available loaders:"
    ls ioncube/ | grep ioncube_loader_lin
    exit 1
fi

# ---- Copy loader to extension directory ----
echo "Copying loader to $EXT_DIR ..."
cp "$LOADER_FILE" "$EXT_DIR/"

LOADER_PATH="${EXT_DIR}/ioncube_loader_lin_${PHP_VERSION}.so"

# ---- Create ini files for FPM and CLI ----
FPM_INI="/etc/php/${PHP_VERSION}/fpm/conf.d/00-ioncube.ini"
CLI_INI="/etc/php/${PHP_VERSION}/cli/conf.d/00-ioncube.ini"

if [ -d "/etc/php/${PHP_VERSION}/fpm/conf.d" ]; then
    echo "zend_extension = ${LOADER_PATH}" > "$FPM_INI"
    echo -e "${GREEN}Created: $FPM_INI${NC}"
fi

if [ -d "/etc/php/${PHP_VERSION}/cli/conf.d" ]; then
    echo "zend_extension = ${LOADER_PATH}" > "$CLI_INI"
    echo -e "${GREEN}Created: $CLI_INI${NC}"
fi

# ---- Restart PHP-FPM for this version ----
FPM_SERVICE="php${PHP_VERSION}-fpm"
if systemctl list-units --type=service --all | grep -q "$FPM_SERVICE"; then
    echo "Restarting $FPM_SERVICE ..."
    systemctl restart "$FPM_SERVICE"
    echo -e "${GREEN}$FPM_SERVICE restarted successfully.${NC}"
else
    echo -e "${YELLOW}Warning: $FPM_SERVICE service not found. Skipping restart.${NC}"
fi

# ---- Verify installation ----
echo ""
echo -e "${YELLOW}=== Verification ===${NC}"
$PHP_BIN -v

echo ""
if $PHP_BIN -v | grep -qi "ionCube"; then
    echo -e "${GREEN}✅ ionCube Loader successfully installed for PHP ${PHP_VERSION} (CLI).${NC}"
else
    echo -e "${RED}⚠ ionCube Loader not detected in CLI output. Please check manually.${NC}"
fi

echo ""
echo "To verify on FPM (web), create a temporary PHP file in your site's htdocs:"
echo '  echo '"'"'<?php echo extension_loaded("ionCube Loader") ? "ionCube Active: ".ioncube_loader_version() : "Not loaded"; ?>'"'"' > /path/to/htdocs/check.php'
echo "Then visit it in your browser, and delete the file afterward."
echo ""
echo -e "${GREEN}Done.${NC}"
