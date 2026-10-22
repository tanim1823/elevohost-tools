#!/bin/bash

clear
echo "=========================================="
echo "    CyberPanel Universal PHP Changer"
echo "=========================================="
echo ""

# Show available LSPHP versions on the server
echo "Available LSPHP Versions on this server:"
echo "----------------------------------------"
ls -d /usr/local/lsws/lsphp* 2>/dev/null | awk -F'lsphp' '{print "- PHP " substr($2,1,1) "." substr($2,2)}'
echo "----------------------------------------"
echo ""

# Ask user for version input with a default value of PHP 8.3
read -p "Enter target PHP version [Default: PHP 8.3]: " INPUT_PHP

# If user pressed enter without typing anything, fallback to PHP 8.3
if [ -z "$INPUT_PHP" ]; then
    NEW_PHP="PHP 8.3"
else
    NEW_PHP="$INPUT_PHP"
fi

LSPHP_VER=$(echo "$NEW_PHP" | tr -d ' .')

echo ""
echo "=========================================="
echo " Switching all websites to: $NEW_PHP"
echo "=========================================="

# 1. Update/Install LSPHP packages via yum/dnf or apt
echo "[1/5] Updating LSPHP packages..."
yum update 'lsphp*' -y 2>/dev/null || apt-get update && apt-get install -y "lsphp${LSPHP_VER#PHP}" 2>/dev/null || true

# 2. Kill stuck/hanging CyberPanel processes
echo "[2/5] Cleaning stuck background processes..."
pkill -9 -f lswsgi 2>/dev/null || true
pkill -9 -f lscpd 2>/dev/null || true

# 3. Update PHP version in CyberPanel Database
echo "[3/5] Updating database for all websites to $NEW_PHP..."
mysql -e "UPDATE cyberpanel.websiteFunctions_websites SET phpSelection = '$NEW_PHP';"

# 4. Update Vhost External App Handlers for OpenLiteSpeed
echo "[4/5] Syncing OpenLiteSpeed Vhost configs..."
sed -i -E "s/path[[:space:]]+\/usr\/local\/lsws\/lsphp[0-9]+\/bin\/lsphp/path \/usr\/local\/lsws\/lsphp${LSPHP_VER#PHP}\/bin\/lsphp/g" /usr/local/lsws/conf/vhosts/*/vhost.conf 2>/dev/null || true

# 5. Restart All Core Services
echo "[5/5] Restarting OpenLiteSpeed and CyberPanel Services..."
systemctl restart lsws
systemctl restart lscpd

echo ""
echo "=========================================="
echo " SUCCESS! Current Website PHP Status:"
echo "=========================================="
# Show final status table of all websites
mysql -e "SELECT domain, phpSelection FROM cyberpanel.websiteFunctions_websites;"
echo "=========================================="
