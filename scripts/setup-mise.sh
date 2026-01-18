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

    # Define the activation command based on shell type
    local activate_cmd=""
    if [ "$shell_type" == "fish" ]; then
        # Fish syntax: mise activate fish | source
        activate_cmd="$MISE_BIN activate fish | source"
    else
        # Bash/Zsh syntax: eval "$(mise activate zsh)"
        activate_cmd="eval \"\$($MISE_BIN activate $shell_type)\""
    fi

    # Only proceed if the config file exists (or the dir exists for fish)
    if [ -f "$config_file" ] || [ "$shell_type" == "fish" ]; then

        # Create fish config if it doesn't exist but the dir does
        if [ "$shell_type" == "fish" ] && [ ! -f "$config_file" ]; then
            if [ -d "$(dirname "$config_file")" ]; then
                 touch "$config_file"
            else
                 # If fish dir doesn't exist, user probably doesn't use fish. Skip.
                 return
            fi
        fi

        echo "${WHITE}Checking $config_file...${RESET}"

        # A. Add mise hook (The Core)
        if grep -Fq "$MISE_BIN activate $shell_type" "$config_file"; then
            echo "${YELLOW}   - Mise hook already present.${RESET}"
        else
            # Backup
            cp "$config_file" "${config_file}.pre-mise"
            echo "${WHITE}   - Adding mise hook...${RESET}"
            echo "" >> "$config_file"
            echo "$activate_cmd" >> "$config_file"
        fi

        # B. Inject Custom Lines from shell-config.list
        if [ -f "$SHELL_CONFIG_LIST" ]; then
            echo "${WHITE}   - processing shell-config.list...${RESET}"
            while IFS= read -r line || [ -n "$line" ]; do
                [[ "$line" =~ ^#.* ]] && continue
                [[ -z "$line" ]] && continue

                # Warning for Fish users regarding syntax
                if [ "$shell_type" == "fish" ] && [[ "$line" == export* ]]; then
                    echo "${YELLOW}     ! Skipping 'export' for fish (syntax incompatible): $line${RESET}"
                    continue
                fi

                if grep -Fq "$line" "$config_file"; then
                     : # Do nothing
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
update_shell_config "$HOME/.config/fish/config.fish" "fish"

# --- 4. Install Tools from Repo Config ---
if [ -f "./mise.toml" ]; then
    echo "${WHITE}Found mise.toml. Installing tools...${RESET}"
    "$MISE_BIN" install

    if [ -f "uv-tools.list" ]; then
        echo "${WHITE}Installing uv tools from uv-tools.list...${RESET}"
        "$MISE_BIN" run install-uv-tools
    fi
else
    echo "${YELLOW}WARNING: No mise.toml found.${RESET}"
fi

# --- 5. Verify ---
echo "${WHITE}Running verification...${RESET}"
"$(dirname "$0")/verify-mise.sh"

echo "${GREEN}Setup complete! Please restart your terminal.${RESET}"