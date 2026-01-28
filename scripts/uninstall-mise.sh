#!/bin/bash
set -e

# Load shared helpers
# shellcheck source=./common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# --- Configuration ---
MISE_BIN="$HOME/.local/bin/mise"
MISE_DATA_DIR="$HOME/.local/share/mise"
MISE_CONFIG_DIR="$HOME/.config/mise"
GLOBAL_MISE_CONFIG="$MISE_CONFIG_DIR/config.toml"

# Markers
BLOCK_START="# --- MANAGED BY MISE-SETUP (START) ---"
BLOCK_END="# --- MANAGED BY MISE-SETUP (END) ---"
GLOBAL_BLOCK_START="# --- MANAGED BY mise-uv-test (START) ---"
GLOBAL_BLOCK_END="# --- MANAGED BY mise-uv-test (END) ---"

# --- 0. Best-effort: if we're running inside zsh, unregister any in-memory mise hooks ---
# This prevents the current shell session from trying to call the removed mise binary
# on the next prompt render.
if [ -n "${ZSH_VERSION:-}" ]; then
    # Remove any precmd hook entries referencing mise
    # shellcheck disable=SC2016
    precmd_functions=(${precmd_functions:#*_mise_*})
    # Unset common hook functions if present
    unset -f _mise_hook_precmd 2>/dev/null || true
    unset -f _mise_hook_chpwd 2>/dev/null || true
    unset -f _mise_hook_preexec 2>/dev/null || true
fi

# --- 1. Remove mise Binaries and Data ---
echo "${YELLOW}Removing mise binaries and data...${RESET}"
rm -f "$MISE_BIN"
rm -rf "$MISE_DATA_DIR"

# --- 1b. Remove managed global tools block (keep user config) ---
if [ -f "$GLOBAL_MISE_CONFIG" ]; then
    echo "${WHITE}Cleaning global mise config ($GLOBAL_MISE_CONFIG)...${RESET}"
    if grep -Fq "$GLOBAL_BLOCK_START" "$GLOBAL_MISE_CONFIG"; then
        cp "$GLOBAL_MISE_CONFIG" "${GLOBAL_MISE_CONFIG}.bak" || true
        sed "/^$GLOBAL_BLOCK_START$/,/^$GLOBAL_BLOCK_END$/d" "$GLOBAL_MISE_CONFIG" > "${GLOBAL_MISE_CONFIG}.tmp" && \
        mv "${GLOBAL_MISE_CONFIG}.tmp" "$GLOBAL_MISE_CONFIG"
        echo "${GREEN}   - Removed managed tools block.${RESET}"
    else
        echo "${YELLOW}   - No managed tools block found.${RESET}"
    fi
fi

# Keep ~/.config/mise by default; it's user config.
# If the directory is empty after cleanup, it can be removed.
if [ -d "$MISE_CONFIG_DIR" ] && [ -z "$(ls -A "$MISE_CONFIG_DIR" 2>/dev/null)" ]; then
    rmdir "$MISE_CONFIG_DIR" 2>/dev/null || true
fi

# --- 2. Helper to Clean Shell Configs ---
clean_shell_config() {
    local config_file="$1"

    if [ -f "$config_file" ]; then
        echo "${WHITE}Cleaning $config_file...${RESET}"

        # Check if either marker or legacy line exists
        if grep -Fq "$BLOCK_START" "$config_file" || grep -Fq "mise activate" "$config_file" || grep -Fq "$MISE_BIN activate" "$config_file"; then
            cp "$config_file" "${config_file}.bak"

            # 1. Remove the Managed Block
            # 2. Remove legacy floating lines (cleanup for old versions)
            # 3. Remove any remaining eval lines that reference the exact binary path
            sed "/^$BLOCK_START$/,/^$BLOCK_END$/d" "$config_file" | \
            grep -Fv "mise activate" | \
            grep -Fv "$MISE_BIN activate" | \
            grep -Fv "$MISE_BIN\" activate" > "${config_file}.tmp" && \
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

# Also clean common backups created by this repo's installer
clean_shell_config "$HOME/.zshrc.bak"
clean_shell_config "$HOME/.bashrc.bak"
clean_shell_config "$HOME/.bash_profile.bak"

echo "${GREEN}Uninstall complete.${RESET}"
echo "${YELLOW}NOTE: If you ran uninstall from an already-open terminal, restart the shell/terminal to clear any previously loaded mise hooks.${RESET}"
