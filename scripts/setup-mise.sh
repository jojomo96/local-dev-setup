#!/bin/bash
set -e

# Load shared helpers
# shellcheck source=./common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# --- Configuration ---
MISE_BIN="$HOME/.local/bin/mise"
SHELL_CONFIG_LIST="./shell-config.list"

# Markers for the managed block
BLOCK_START="# --- MANAGED BY MISE-SETUP (START) ---"
BLOCK_END="# --- MANAGED BY MISE-SETUP (END) ---"

# --- 1. Install mise (Idempotent) ---
echo "${WHITE}Checking for mise...${RESET}"
if [ ! -f "$MISE_BIN" ]; then
    echo "${WHITE}Installing mise...${RESET}"
    curl https://mise.run | sh
    echo "${GREEN}mise installed to $MISE_BIN${RESET}"
else
    echo "${GREEN}mise is already installed.${RESET}"
fi

# --- 2. Helper: Update Shell Configs (Block Strategy) ---
update_shell_config() {
    local config_file="$1"
    local shell_type="$2"

    # 1. Determine Activation Command
    local activate_cmd=""
    if [ "$shell_type" == "fish" ]; then
        activate_cmd="$MISE_BIN activate fish | source"
    else
        activate_cmd="eval \"\$($MISE_BIN activate $shell_type)\""
    fi

    # 2. Check/Create Config File
    if [ "$shell_type" == "fish" ]; then
        # Ensure fish config dir exists
        if [ ! -d "$(dirname "$config_file")" ]; then return; fi
        if [ ! -f "$config_file" ]; then touch "$config_file"; fi
    fi

    if [ -f "$config_file" ]; then
        echo "${WHITE}Updating $config_file...${RESET}"

        # Create a temp file
        local tmp_file="${config_file}.tmp"

        # --- A. CLEANUP STEP ---
        # 1. Remove the existing managed block (if any)
        # 2. Remove legacy floating "mise activate" lines (from old version of script)
        # We use sed to strip the block range, then grep -v to kill floating legacy lines
        sed "/^$BLOCK_START$/,/^$BLOCK_END$/d" "$config_file" | \
        grep -Fv "$MISE_BIN activate $shell_type" > "$tmp_file"

        # --- B. GENERATE NEW BLOCK ---
        {
            echo ""
            echo "$BLOCK_START"
            echo "# This block is auto-generated. Edits will be overwritten."
            echo "$activate_cmd"

            # Inject Custom Lines from list
            if [ -f "$SHELL_CONFIG_LIST" ]; then
                echo "# --- Custom Configs ---"
                while IFS= read -r line || [ -n "$line" ]; do
                    [[ "$line" =~ ^#.* ]] && continue
                    [[ -z "$line" ]] && continue

                    # Fish Compatibility Check
                    if [ "$shell_type" == "fish" ] && [[ "$line" == export* ]]; then
                        echo "# [SKIPPED export] $line"
                    else
                        echo "$line"
                    fi
                done < "$SHELL_CONFIG_LIST"
            fi

            echo "$BLOCK_END"
        } >> "$tmp_file"

        # --- C. APPLY ---
        # Compare (ignoring whitespace) to see if we actually changed anything
        # to avoid changing file modification time unnecessarily
        if cmp -s "$config_file" "$tmp_file"; then
             rm "$tmp_file"
             echo "${YELLOW}   - Configuration already up to date.${RESET}"
        else
             # Backup original
             cp "$config_file" "${config_file}.bak"
             mv "$tmp_file" "$config_file"
             echo "${GREEN}   - Updated configuration block (Backup: .bak)${RESET}"
        fi
    fi
}

# --- 3. Apply to Shells ---
update_shell_config "$HOME/.bashrc" "bash"
update_shell_config "$HOME/.bash_profile" "bash"
update_shell_config "$HOME/.zshrc" "zsh"
update_shell_config "$HOME/.config/fish/config.fish" "fish"

# --- 4. Install Tools ---
if [ -f "./mise.toml" ]; then
    echo "${WHITE}Found mise.toml. Installing tools...${RESET}"
    "$MISE_BIN" install
    if [ -f "uv-tools.list" ]; then
        "$MISE_BIN" run install-uv-tools
    fi
fi

# --- 5. Verify ---
echo "${WHITE}Running verification...${RESET}"
"$(dirname "$0")/verify-mise.sh"

echo "${GREEN}Setup complete! Please restart your terminal.${RESET}"