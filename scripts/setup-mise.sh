#!/bin/bash
set -e  # Exit immediately if a command fails

# Load shared helpers
# shellcheck source=./common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# --- Configuration ---
MISE_BIN="$HOME/.local/bin/mise"
SHELL_CONFIG_LIST="./shell-config.list"

# --- 1. Install mise (Idempotent) ---
echo "${WHITE}Checking for mise...${RESET}"
if [ ! -f "$MISE_BIN" ]; then
    echo "${WHITE}Installing mise...${RESET}"
    curl https://mise.run | sh
    echo "${GREEN}mise installed to $MISE_BIN${RESET}"
else
    echo "${GREEN}mise is already installed.${RESET}"
fi

# --- 2. Helper: Update Shell Configs ---
update_shell_config() {
    local config_file="$1"
    local shell_type="$2"
    local activate_cmd="eval \"\$($MISE_BIN activate $shell_type)\""

    if [ -f "$config_file" ]; then
        echo "${WHITE}Checking $config_file...${RESET}"

        # A. Add mise hook (The Core)
        if grep -Fq "$activate_cmd" "$config_file"; then
            echo "${YELLOW}   - Mise hook already present.${RESET}"
        else
            # Backup before first touch
            cp "$config_file" "${config_file}.pre-mise"
            echo "${WHITE}   - Adding mise hook...${RESET}"
            echo "" >> "$config_file"
            echo "$activate_cmd" >> "$config_file"
        fi

        # B. Inject Custom Lines from shell-config.list (The New System)
        if [ -f "$SHELL_CONFIG_LIST" ]; then
            echo "${WHITE}   - processing shell-config.list...${RESET}"
            while IFS= read -r line || [ -n "$line" ]; do
                # Skip comments and empty lines
                [[ "$line" =~ ^#.* ]] && continue
                [[ -z "$line" ]] && continue

                # Check if this specific line exists in the config
                if grep -Fq "$line" "$config_file"; then
                     : # Do nothing, it exists
                else
                     echo "${GREEN}     + Adding: $line${RESET}"
                     echo "$line" >> "$config_file"
                fi
            done < "$SHELL_CONFIG_LIST"
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
    "$MISE_BIN" install

    echo "${WHITE}Installing uv tools from uv-tools.list...${RESET}"
    "$MISE_BIN" run install-uv-tools
else
    echo "${YELLOW}WARNING: No mise.toml found.${RESET}"
fi

# --- 5. Verify ---
echo "${WHITE}Running verification...${RESET}"
"$(dirname "$0")/verify-mise.sh"

echo "${GREEN}Setup complete! Please restart your terminal.${RESET}"