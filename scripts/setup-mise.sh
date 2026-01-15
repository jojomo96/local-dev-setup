#!/bin/bash
set -e  # Exit immediately if a command fails

# --- Configuration ---
MISE_BIN="$HOME/.local/bin/mise"

# --- 1. Install mise (Idempotent) ---
echo "🔍 Checking for mise..."
if [ ! -f "$MISE_BIN" ]; then
    echo "📦 Installing mise..."
    curl https://mise.run | sh
    echo "✅ mise installed to $MISE_BIN"
else
    echo "✅ mise is already installed."
fi

# --- 2. Helper Function to Update Configs ---
update_shell_config() {
    local config_file="$1"
    local shell_type="$2"
    local activate_cmd="eval \"\$($MISE_BIN activate $shell_type)\""

    if [ -f "$config_file" ]; then
        echo "📝 Checking $config_file..."

        # Check if the file already contains the activation command
        if grep -Fq "$activate_cmd" "$config_file"; then
            echo "   - Hook already present. Skipping."
        else
            # --- BACKUP STEP ---
            local backup_file="${config_file}.pre-mise"
            cp "$config_file" "$backup_file"
            echo "   - 🛡️  Backup created: $backup_file"

            # Append the hook
            echo "   - Adding mise hook to $config_file..."
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
    echo "⬇️  Installing tools from ./mise.toml..."
    "$MISE_BIN" install
fi

echo "🎉 Setup complete! Restart your terminal."