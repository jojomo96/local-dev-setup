#!/bin/bash
set -e

# Load shared helpers
# shellcheck source=./common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Ensure we run relative to the repo root (so ./mise.toml, ./shell-config.list resolve correctly)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# --- Configuration ---
MISE_BIN="$HOME/.local/bin/mise"
SHELL_CONFIG_LIST="$REPO_ROOT/shell-config.list"

# Global mise config so tools are available outside this repo
GLOBAL_MISE_DIR="$HOME/.config/mise"
GLOBAL_MISE_CONFIG="$GLOBAL_MISE_DIR/config.toml"
GLOBAL_BLOCK_START="# --- MANAGED BY mise-uv-test (START) ---"
GLOBAL_BLOCK_END="# --- MANAGED BY mise-uv-test (END) ---"

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
            echo "# Ensure the mise install location is on PATH"
            if [ "$shell_type" == "fish" ]; then
                echo "fish_add_path -g $HOME/.local/bin"
                echo "# Activate mise for interactive shells"
                echo "status --is-interactive; and $activate_cmd"
            else
                echo "export PATH=\"$HOME/.local/bin:\$PATH\""
                echo "# Activate mise for interactive shells"
                echo "case \"\$-\" in *i*) $activate_cmd ;; esac"
            fi

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

# --- 2b. Ensure a Global mise Config (Idempotent) ---
ensure_global_mise_config() {
    mkdir -p "$GLOBAL_MISE_DIR"
    if [ ! -f "$GLOBAL_MISE_CONFIG" ]; then
        touch "$GLOBAL_MISE_CONFIG"
    fi

    local tmp_file="${GLOBAL_MISE_CONFIG}.tmp"

    # Remove existing managed block (if any)
    sed "/^$GLOBAL_BLOCK_START$/,/^$GLOBAL_BLOCK_END$/d" "$GLOBAL_MISE_CONFIG" > "$tmp_file"

    # Append our managed block
    {
        echo ""
        echo "$GLOBAL_BLOCK_START"
        echo "# This block is auto-generated. Edits will be overwritten."
        echo "[tools]"
        echo "\"go:github.com/stackitcloud/stackit-cli\" = \"latest\""
        echo "awscli = \"latest\""
        echo "terraform = \"latest\""
        echo "tflint = \"latest\""
        echo "terraform-docs = \"latest\""
        echo "kubectl = \"latest\""
        echo "helm = \"latest\""
        echo "k9s = \"latest\""
        echo "krew = \"latest\""
        echo "jq = \"latest\""
        echo "yq = \"latest\""
        echo "go = \"latest\""
        echo "python = \"3.12\""
        echo "uv = \"latest\""
        echo "$GLOBAL_BLOCK_END"
    } >> "$tmp_file"

    if cmp -s "$GLOBAL_MISE_CONFIG" "$tmp_file"; then
        rm "$tmp_file"
        echo "${YELLOW}Global mise config already up to date (${GLOBAL_MISE_CONFIG}).${RESET}"
    else
        cp "$GLOBAL_MISE_CONFIG" "${GLOBAL_MISE_CONFIG}.bak" 2>/dev/null || true
        mv "$tmp_file" "$GLOBAL_MISE_CONFIG"
        echo "${GREEN}Updated global mise config (${GLOBAL_MISE_CONFIG}).${RESET}"
    fi
}

# --- 3. Apply to Shells ---
update_shell_config "$HOME/.bashrc" "bash"
update_shell_config "$HOME/.bash_profile" "bash"
update_shell_config "$HOME/.zshrc" "zsh"
update_shell_config "$HOME/.config/fish/config.fish" "fish"

echo "${WHITE}Ensuring global mise config...${RESET}"
ensure_global_mise_config

# --- 4. Install Tools ---
# 4a) Global tools (available everywhere)
echo "${WHITE}Installing global tools...${RESET}"
"$MISE_BIN" install

# 4b) Project tools (if this repo has a mise.toml)
if [ -f "./mise.toml" ]; then
    echo "${WHITE}Found mise.toml. Installing project tools...${RESET}"
    "$MISE_BIN" install
    if [ -f "uv-tools.list" ]; then
        "$MISE_BIN" run install-uv-tools
    fi
fi

# --- 5. Verify ---
echo "${WHITE}Running verification...${RESET}"
"$(dirname "$0")/verify-mise.sh"

echo "${GREEN}Setup complete! Please restart your terminal.${RESET}"