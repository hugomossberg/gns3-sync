#!/usr/bin/env bash
# =====================================================================
# GNS3Sync Installer
# Automated GitOps & Disaster Recovery documentation for GNS3 topologies
# =====================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}             GNS3Sync Universal Installer             ${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. Root / Sudo Detection
IS_ROOT=false
if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
fi

# Determine target binary directory
if [[ "$IS_ROOT" == true ]] || command -v sudo >/dev/null 2>&1; then
    BIN_DIR="/usr/local/bin"
    CONFIG_DIR="/etc/gns3sync"
    USE_SUDO=true
else
    BIN_DIR="${HOME}/.local/bin"
    CONFIG_DIR="${HOME}/.config/gns3sync"
    USE_SUDO=false
    mkdir -p "${BIN_DIR}"
fi

# 2. Dependency Checks
echo -e "\n${BLUE}[1/5] Checking system dependencies...${NC}"

check_tool() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "  ✔ $1: ${GREEN}installed${NC}"
        return 0
    else
        echo -e "  ✖ $1: ${YELLOW}missing${NC}"
        return 1
    fi
}

MISSING_DEPS=()
check_tool python3 || MISSING_DEPS+=("python3")
check_tool git || MISSING_DEPS+=("git")
check_tool qemu-nbd || MISSING_DEPS+=("qemu-utils")
check_tool strings || MISSING_DEPS+=("binutils")

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo -e "\n${YELLOW}Some recommended dependencies are missing: ${MISSING_DEPS[*]}${NC}"
    if command -v apt-get >/dev/null 2>&1 && [[ "$USE_SUDO" == true ]]; then
        read -r -p "Would you like to install them now using apt? [Y/n] " install_apt
        if [[ "$install_apt" != "n" && "$install_apt" != "N" ]]; then
            echo -e "${BLUE}Installing dependencies via apt...${NC}"
            if [[ "$IS_ROOT" == true ]]; then
                apt-get update && apt-get install -y "${MISSING_DEPS[@]}" python3-yaml
            else
                sudo apt-get update && sudo apt-get install -y "${MISSING_DEPS[@]}" python3-yaml
            fi
        fi
    else
        echo -e "${YELLOW}Please install the missing tools manually using your package manager.${NC}"
    fi
fi

# 3. Install Executables
echo -e "\n${BLUE}[2/5] Installing GNS3Sync binaries to ${BIN_DIR}...${NC}"

if [[ "$IS_ROOT" == true ]]; then
    cp "${SCRIPT_DIR}/bin/gns3sync" "${BIN_DIR}/gns3sync"
    cp "${SCRIPT_DIR}/bin/gns3-switch" "${BIN_DIR}/gns3-switch"
    chmod +x "${BIN_DIR}/gns3sync" "${BIN_DIR}/gns3-switch"
elif [[ "$USE_SUDO" == true ]]; then
    sudo cp "${SCRIPT_DIR}/bin/gns3sync" "${BIN_DIR}/gns3sync"
    sudo cp "${SCRIPT_DIR}/bin/gns3-switch" "${BIN_DIR}/gns3-switch"
    sudo chmod +x "${BIN_DIR}/gns3sync" "${BIN_DIR}/gns3-switch"
else
    cp "${SCRIPT_DIR}/bin/gns3sync" "${BIN_DIR}/gns3sync"
    cp "${SCRIPT_DIR}/bin/gns3-switch" "${BIN_DIR}/gns3-switch"
    chmod +x "${BIN_DIR}/gns3sync" "${BIN_DIR}/gns3-switch"
fi

echo -e "  ✔ ${GREEN}gns3sync installed to ${BIN_DIR}/gns3sync${NC}"
echo -e "  ✔ ${GREEN}gns3-switch installed to ${BIN_DIR}/gns3-switch${NC}"

# 4. Sudoers Configuration for Out-of-Band VM Disk Inspection
echo -e "\n${BLUE}[3/5] Configuring sudo permissions for out-of-band disk inspection...${NC}"
SUDOERS_FILE="/etc/sudoers.d/gns3sync"
SUDOERS_CONTENT="# Sudo permissions for GNS3Sync out-of-band VM disk inspection
ALL ALL=(root) NOPASSWD: /usr/bin/qemu-nbd, /usr/sbin/partx, /usr/bin/partx, /usr/bin/mount, /usr/bin/umount, /usr/bin/cat, /usr/bin/chown
"

if [[ "$IS_ROOT" == true ]]; then
    echo "${SUDOERS_CONTENT}" > "${SUDOERS_FILE}"
    chmod 0440 "${SUDOERS_FILE}"
    echo -e "  ✔ ${GREEN}Created ${SUDOERS_FILE}${NC}"
elif [[ "$USE_SUDO" == true ]] && sudo -n true 2>/dev/null; then
    echo "${SUDOERS_CONTENT}" | sudo tee "${SUDOERS_FILE}" >/dev/null
    sudo chmod 0440 "${SUDOERS_FILE}"
    echo -e "  ✔ ${GREEN}Created ${SUDOERS_FILE}${NC}"
else
    echo -e "  ℹ ${YELLOW}Skipped sudoers setup. To inspect QEMU VM disks without root prompts, add disk utilities to sudoers.${NC}"
fi

# 5. Configuration Setup
echo -e "\n${BLUE}[4/5] Setting up configuration template...${NC}"
if [[ ! -d "${CONFIG_DIR}" ]]; then
    if [[ "$IS_ROOT" == true ]]; then
        mkdir -p "${CONFIG_DIR}"
    elif [[ "$USE_SUDO" == true ]]; then
        sudo mkdir -p "${CONFIG_DIR}"
        sudo chown "${USER}:${USER}" "${CONFIG_DIR}"
    else
        mkdir -p "${CONFIG_DIR}"
    fi
fi

if [[ ! -f "${CONFIG_DIR}/config.yaml" ]]; then
    if [[ "$IS_ROOT" == true ]]; then
        cp "${SCRIPT_DIR}/config.example.yaml" "${CONFIG_DIR}/config.yaml"
    elif [[ "$USE_SUDO" == true ]]; then
        sudo cp "${SCRIPT_DIR}/config.example.yaml" "${CONFIG_DIR}/config.yaml"
        sudo chown "${USER}:${USER}" "${CONFIG_DIR}/config.yaml"
    else
        cp "${SCRIPT_DIR}/config.example.yaml" "${CONFIG_DIR}/config.yaml"
    fi
    echo -e "  ✔ ${GREEN}Initialized configuration template at ${CONFIG_DIR}/config.yaml${NC}"
else
    echo -e "  ✔ ${BLUE}Existing configuration found at ${CONFIG_DIR}/config.yaml (preserved)${NC}"
fi

# 6. Periodic Synchronization Setup (Systemd or Cron)
echo -e "\n${BLUE}[5/5] Background sync configuration...${NC}"
if command -v systemctl >/dev/null 2>&1 && [[ -d "/etc/systemd/system" ]] && [[ "$USE_SUDO" == true ]]; then
    read -r -p "Would you like to install and enable the systemd timer (sync every 30m)? [Y/n] " enable_systemd
    if [[ "$enable_systemd" != "n" && "$enable_systemd" != "N" ]]; then
        if [[ "$IS_ROOT" == true ]]; then
            cp "${SCRIPT_DIR}/systemd/gns3sync.service" /etc/systemd/system/
            cp "${SCRIPT_DIR}/systemd/gns3sync.timer" /etc/systemd/system/
            systemctl daemon-reload
            systemctl enable --now gns3sync.timer
        else
            sudo cp "${SCRIPT_DIR}/systemd/gns3sync.service" /etc/systemd/system/
            sudo cp "${SCRIPT_DIR}/systemd/gns3sync.timer" /etc/systemd/system/
            sudo systemctl daemon-reload
            sudo systemctl enable --now gns3sync.timer
        fi
        echo -e "  ✔ ${GREEN}gns3sync.timer activated!${NC}"
    fi
else
    echo -e "  ℹ ${YELLOW}To run periodically via crontab, add: */30 * * * * ${BIN_DIR}/gns3sync sync >/dev/null 2>&1${NC}"
fi

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}             Installation Complete! 🎉               ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "Quickstart:"
echo -e "  1. Run ${BLUE}gns3sync init${NC} to configure your GNS3 directory and GitHub repo"
echo -e "  2. Run ${BLUE}gns3sync status${NC} to verify connectivity"
echo -e "  3. Run ${BLUE}gns3-switch${NC} to select your active project"
echo -e "  4. Run ${BLUE}gns3sync${NC} to perform a manual GitOps sync and push"
echo -e "\nEnjoy automated, multi-vendor disaster recovery for GNS3! 🚀\n"
