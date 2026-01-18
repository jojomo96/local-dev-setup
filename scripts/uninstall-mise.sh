#!/bin/bash
set -e

# Load shared helpers
# shellcheck source=./common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# --- Configuration ---
MISE_BIN="$HOME/.local/bin/mise"
MISE_DATA_DIR="$HOME/.local/share/mise"
MISE_CONFIG_DIR="$HOME/.config/mise"
SHELL_CONFIG_LIST="./shell-config.list"

# --- 1. Remove mise Binaries and Data ---
echo "${YELLOW}Removing mise binaries and data...${RESET}"
rm -f "$MISE_BIN"
rm -rf "$MISE_DATA_DIR"
rm -rf "$MISE_CONFIG_DIR"

# --- 2. Helper to Clean Shell Configs ---
clean_shell_config() {
    local config_file="$1"
    local mise_pattern="mise activate"

    if [ -f "$config_file" ]; then
        echo "${WHITE}Cleaning $config_file...${RESET}"

        # Create backup
        cp "$config_file" "${config_file}.bak"

        # A. Remove Mise Hook
        if grep -q "$mise_pattern" "$config_file"; then
            grep -v "$mise_pattern" "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
            echo "${GREEN}   - Removed mise hooks${RESET}"
        fi

        # B. Remove Custom Lines from shell-config.list
        if [ -f "$SHELL_CONFIG_LIST" ]; then
            while IFS= read -r line || [ -n "$line" ]; do
                [[ "$line" =~ ^#.* ]] && continue
                [[ -z "$line" ]] && continue

                # Remove this specific line if found
                if grep -Fq "$line" "$config_file"; then
                    grep -Fxv "$line" "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
                    echo "${GREEN}   - Removed custom line: $line${RESET}"
                fi
            done < "$SHELL_CONFIG_LIST"
        fi
    fi
}

# --- 3. Clean Shells ---
clean_shell_config "$HOME/.bashrc"
clean_shell_config "$HOME/.bash_profile"
clean_shell_config "$HOME/.zshrc"

echo "${GREEN}Uninstall complete.${RESET}"