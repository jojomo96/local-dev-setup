#!/usr/bin/env bash
set -euo pipefail

# Load shared helpers (colors, etc.)
# shellcheck source=./common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

DEFAULT_MISE_BIN="$HOME/.local/bin/mise"
GLOBAL_MISE_CONFIG="$HOME/.config/mise/config.toml"
GLOBAL_BLOCK_START="# --- MANAGED BY mise-uv-test (START) ---"
GLOBAL_BLOCK_END="# --- MANAGED BY mise-uv-test (END) ---"

echo "${WHITE}Verifying mise installation...${RESET}"

# 1. Check Binary Existence
if [ -x "$DEFAULT_MISE_BIN" ]; then
  MISE_PATH="$DEFAULT_MISE_BIN"
elif command -v mise >/dev/null 2>&1; then
  MISE_PATH="$(command -v mise)"
else
  echo "${YELLOW}FAIL: mise binary not found.${RESET}"
  echo "${YELLOW}Run: make install${RESET}"
  exit 1
fi
echo "${GREEN}PASS: Binary found at ${MISE_PATH}${RESET}"

# 2. Run 'mise doctor' (The tool you wanted integrated)
# We capture the output because 'mise doctor' returns exit code 1 if not activated,
# which we expect in this context (since the shell isn't restarted yet).
echo "${WHITE}Running 'mise doctor' diagnostics...${RESET}"

if "$MISE_PATH" doctor > /tmp/mise-doctor.log 2>&1; then
    echo "${GREEN}PASS: mise doctor reports healthy setup.${RESET}"
else
    # Doctor failed. Let's analyze why.
    # If it's just "not activated", that is normal for a setup script.
    if grep -q "mise is not activated" /tmp/mise-doctor.log; then
        echo "${GREEN}PASS: mise is installed correctly.${RESET}"
        echo "${YELLOW}NOTE: 'mise doctor' reports 'not activated'. This is normal inside this script.${RESET}"
        echo "${YELLOW}      It will be active once you restart your terminal.${RESET}"
    else
        echo "${YELLOW}FAIL: mise doctor reported issues:${RESET}"
        cat /tmp/mise-doctor.log
        exit 1
    fi
fi

# 3. Check Global mise Config
if [ -f "$GLOBAL_MISE_CONFIG" ]; then
  if sed "/^$GLOBAL_BLOCK_START$/,/^$GLOBAL_BLOCK_END$/!d" "$GLOBAL_MISE_CONFIG" | grep -q "stackitcloud/stackit-cli"; then
    echo "${GREEN}PASS: Global mise config contains managed tools block (${GLOBAL_MISE_CONFIG}).${RESET}"
  else
    echo "${YELLOW}WARN: Global mise config exists but managed tools block is missing or does not include stackit-cli (${GLOBAL_MISE_CONFIG}).${RESET}"
  fi
else
  echo "${YELLOW}WARN: Global mise config not found at ${GLOBAL_MISE_CONFIG}.${RESET}"
fi

# 4. Check Shell Hooks (Manual double-check)
# This ensures the lines actually exist in the config files
check_config() {
    local f="$1"
    if [ -f "$f" ]; then
        if grep -q "mise activate" "$f"; then
             echo "${GREEN}PASS: Activation hook found in $f${RESET}"
        else
             echo "${YELLOW}WARN: Activation hook missing from $f${RESET}"
        fi
    fi
}

check_config "$HOME/.zshrc"
check_config "$HOME/.bashrc"
check_config "$HOME/.bash_profile"

# 5. Verify global tool availability in a fresh interactive zsh from $HOME
# This simulates what the user expects: tools work in arbitrary directories.
if command -v zsh >/dev/null 2>&1; then
  if zsh -ic 'command -v stackit-cli >/dev/null 2>&1'; then
    echo "${GREEN}PASS: stackit-cli is available in a fresh interactive zsh.${RESET}"
  else
    echo "${YELLOW}FAIL: stackit-cli is NOT available in a fresh interactive zsh.${RESET}"
    echo "${YELLOW}      Try: restart terminal or run: source ~/.zshrc${RESET}"
    exit 1
  fi
fi

exit 0

