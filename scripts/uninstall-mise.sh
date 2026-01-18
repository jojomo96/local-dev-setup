#!/bin/bash
set -e

# Load shared helpers
# shellcheck source=./common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# --- Configuration ---
MISE_BIN="$HOME/.local/bin/mise"
MISE_DATA_DIR="$HOME/.local/share/mise"
MISE_CONFIG_DIR="$HOME/.config/mise"

# Markers
BLOCK_START="# --- MANAGED BY MISE-SETUP (START) ---"
BLOCK_END="# --- MANAGED BY MISE-SETUP (END) ---"

# --- 1. Remove mise Binaries and Data ---
echo "${YELLOW}Removing mise binaries and data...${RESET}"
rm -f "$MISE_BIN"
rm -rf "$MISE_DATA_DIR"
rm -rf "$MISE_CONFIG_DIR"

# --- 2. Helper to Clean Shell Configs ---
clean_shell_config() {
    local config_file="$1"

    if [ -f "$config_file" ]; then
        echo "${WHITE}Cleaning $config_file...${RESET}"

        # Check if either marker or legacy line exists
        if grep -Fq "$BLOCK_START" "$config_file" || grep -Fq "mise activate" "$config_file"; then
            cp "$config_file" "${config_file}.bak"

            # 1. Remove the Managed Block
            # 2. Remove legacy floating lines (cleanup for old versions)
            sed "/^$BLOCK_START$/,/^$BLOCK_END$/d" "$config_file" | \
            grep -Fv "mise activate" > "${config_file}.tmp" && \
            mv "${config_file}.tmp" "$config_file"

            echo "${GREEN}   - Removed mise configuration block.${RESET}"
        else
             echo "${YELLOW}   - No configuration found to remove.${RESET}"
        fi
    fi
}

# --- 3. Clean Shells ---
clean_shell_config "$HOME/.bashrc"
clean_shell_config "$HOME/.bash_profile"
clean_shell_config "$HOME/.zshrc"
clean_shell_config "$HOME/.config/fish/config.fish"

echo "${GREEN}Uninstall complete.${RESET}"