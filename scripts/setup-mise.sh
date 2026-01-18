#!/bin/bash
set -e  # Exit immediately if a command fails

# Load shared helpers
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
        if grep -Fq "$activate_cmd" "$config_file"; then
            echo "${GREEN}   - Hook already present. Skipping.${RESET}"
        else
            local backup_file="${config_file}.pre-mise"
            cp "$config_file" "$backup_file"
            echo "${YELLOW}   - Backup created: $backup_file${RESET}"

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

# --- 4. Install Tools from Repo Config ---
if [ -f "./mise.toml" ]; then
    echo "${WHITE}Found mise.toml. Installing tools...${RESET}"

    # Install standard tools (Terraform, kubectl, uv, etc.)
    "$MISE_BIN" install

    # Run the custom task to install uv tools from the list file
    echo "${WHITE}Installing uv tools from uv-tools.list...${RESET}"
    "$MISE_BIN" run install-uv-tools
else
    echo "${YELLOW}WARNING: No mise.toml found in current directory.${RESET}"
    echo "${YELLOW}Please create one or pull the repository correctly.${RESET}"
fi

# --- 5. Verify ---
echo "${WHITE}Running verification...${RESET}"
"$(dirname "$0")/verify-mise.sh"

echo "${GREEN}Setup complete! Please restart your terminal.${RESET}"