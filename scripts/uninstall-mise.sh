#!/bin/bash
set -e

# Load shared helpers (colors, etc.)
# shellcheck source=./common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# --- Configuration ---
MISE_BIN="$HOME/.local/bin/mise"
MISE_DATA_DIR="$HOME/.local/share/mise"
MISE_CONFIG_DIR="$HOME/.config/mise"

# --- 1. Remove mise Binaries and Data ---
echo "${YELLOW}Removing mise binaries and data...${RESET}"

if [ -f "$MISE_BIN" ]; then
    rm "$MISE_BIN"
    echo "${WHITE}   - Deleted $MISE_BIN${RESET}"
else
    echo "${YELLOW}   - Binary not found (skipped)${RESET}"
fi

if [ -d "$MISE_DATA_DIR" ]; then
    rm -rf "$MISE_DATA_DIR"
    echo "${WHITE}   - Deleted data directory $MISE_DATA_DIR${RESET}"
fi

if [ -d "$MISE_CONFIG_DIR" ]; then
    rm -rf "$MISE_CONFIG_DIR"
    echo "${WHITE}   - Deleted config directory $MISE_CONFIG_DIR${RESET}"
fi

# --- 2. Helper Function to Clean Shell Configs ---
clean_shell_config() {
    local config_file="$1"
    local pattern="mise activate"

    if [ -f "$config_file" ]; then
        if grep -q "$pattern" "$config_file"; then
            echo "${WHITE}Cleaning $config_file...${RESET}"

            # Create a backup just in case (.bak)
            cp "$config_file" "${config_file}.bak"

            grep -v "$pattern" "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"

            echo "${GREEN}   - Removed mise hooks from $config_file${RESET}"
        else
            echo "${YELLOW}   - No hooks found in $config_file${RESET}"
        fi
    fi
}

# --- 3. Clean Shells ---
clean_shell_config "$HOME/.bashrc"
clean_shell_config "$HOME/.bash_profile"
clean_shell_config "$HOME/.zshrc"

echo "${GREEN}Uninstall complete. (Backups of config files created as .bak)${RESET}"