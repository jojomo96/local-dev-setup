#!/bin/bash
set -e  # Exit immediately if a command fails

# Load shared helpers (colors, etc.)
# shellcheck source=./common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# --- Configuration ---
MISE_BIN="$HOME/.local/bin/mise"

# --- 1. Install mise (Idempotent) ---
echo "${WHITE}Checking for mise...${RESET}"
if [ ! -f "$MISE_BIN" ]; then
    echo "${WHITE}Installing mise...${RESET}"
    curl https://mise.run | sh
    echo "${GREEN}mise installed to $MISE_BIN${RESET}"
else
    echo "${GREEN}mise is already installed.${RESET}"
fi

# --- 2. Helper Function to Update Configs ---
update_shell_config() {
    local config_file="$1"
    local shell_type="$2"
    local activate_cmd="eval \"\$($MISE_BIN activate $shell_type)\""

    if [ -f "$config_file" ]; then
        echo "${WHITE}Checking $config_file...${RESET}"

        # Check if the file already contains the activation command
        if grep -Fq "$activate_cmd" "$config_file"; then
            echo "${YELLOW}   - Hook already present. Skipping.${RESET}"
        else
            # --- BACKUP STEP ---
            local backup_file="${config_file}.pre-mise"
            cp "$config_file" "$backup_file"
            echo "${YELLOW}   - Backup created: $backup_file${RESET}"

            # Append the hook
            echo "${WHITE}   - Adding mise hook to $config_file...${RESET}"
            echo "" >> "$config_file"
            echo "$activate_cmd" >> "$config_file"
        fi
    fi
}

# --- 3. Apply to Shells ---
update_shell_config "$HOME/.bashrc" "bash"
update_shell_config "$HOME/.bash_profile" "bash"
update_shell_config "$HOME/.zshrc" "zsh"

# --- 4. Install Tools ---
if [ -f "./mise.toml" ]; then
    echo "${WHITE}Installing tools from ./mise.toml...${RESET}"
    "$MISE_BIN" install
fi

echo "${GREEN}Setup complete! Restart your terminal.${RESET}"
