#!/bin/bash
set -e

# --- Configuration ---
MISE_BIN="$HOME/.local/bin/mise"
MISE_DATA_DIR="$HOME/.local/share/mise"
MISE_CONFIG_DIR="$HOME/.config/mise"

# --- 1. Remove mise Binaries and Data ---
echo "Removing mise binaries and data..."

if [ -f "$MISE_BIN" ]; then
    rm "$MISE_BIN"
    echo "   - Deleted $MISE_BIN"
else
    echo "   - Binary not found (skipped)"
fi

if [ -d "$MISE_DATA_DIR" ]; then
    rm -rf "$MISE_DATA_DIR"
    echo "   - Deleted data directory $MISE_DATA_DIR"
fi

if [ -d "$MISE_CONFIG_DIR" ]; then
    rm -rf "$MISE_CONFIG_DIR"
    echo "   - Deleted config directory $MISE_CONFIG_DIR"
fi

# --- 2. Helper Function to Clean Shell Configs ---
clean_shell_config() {
    local config_file="$1"
    # The pattern to look for (escaped for sed)
    # We look for the line containing 'mise activate'
    local pattern="mise activate"

    if [ -f "$config_file" ]; then
        if grep -q "$pattern" "$config_file"; then
            echo "Cleaning $config_file..."

            # Create a backup just in case (.bak)
            cp "$config_file" "${config_file}.bak"

            # Use sed to delete any line containing the pattern
            # -i.bak works on both macOS (BSD) and Linux (GNU) sed variants safely
            # On macOS, '' is required after -i, on Linux it isn't.
            # We use a portable approach: temp file

            grep -v "$pattern" "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"

            echo "   - Removed mise hooks from $config_file"
        else
            echo "   - No hooks found in $config_file"
        fi
    fi
}

# --- 3. Clean Shells ---
clean_shell_config "$HOME/.bashrc"
clean_shell_config "$HOME/.bash_profile"
clean_shell_config "$HOME/.zshrc"

echo "Uninstall complete. (Backups of config files created as .bak)"
