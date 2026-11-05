#!/usr/bin/env bash
# =====================================================================
# GNS3Sync Uninstaller
# =====================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}Uninstalling GNS3Sync...${NC}"

# Stop systemd timer if present
if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl stop gns3sync.timer 2>/dev/null || true
    sudo systemctl disable gns3sync.timer 2>/dev/null || true
    sudo rm -f /etc/systemd/system/gns3sync.service /etc/systemd/system/gns3sync.timer
    sudo systemctl daemon-reload 2>/dev/null || true
fi

# Remove binaries
sudo rm -f /usr/local/bin/gns3sync /usr/local/bin/gns3-switch
rm -f "${HOME}/.local/bin/gns3sync" "${HOME}/.local/bin/gns3-switch"

# Remove sudoers file
sudo rm -f /etc/sudoers.d/gns3sync

echo -e "${GREEN}GNS3Sync has been uninstalled.${NC}"
echo -e "Note: Configuration directories (/etc/gns3sync, ~/.config/gns3sync) and your export repository were preserved."
