#!/bin/bash
set -e  # Exit immediately if a command fails

# --- Configuration ---
MISE_BIN="$HOME/.local/bin/mise"

# --- 1. Install mise (Idempotent) ---
echo "🔍 Checking for mise..."
if [ ! -f "$MISE_BIN" ]; then
    echo "📦 Installing mise..."
    # We use -s to silence progress, but keep errors
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

    # Only proceed if the config file exists (e.g., don't create .zshrc if user only uses bash)
    if [ -f "$config_file" ]; then
        echo "📝 Checking $config_file..."

        # Check if the file already contains the activation command
        # We grep for the command string to ensure idempotency
        if grep -Fq "$activate_cmd" "$config_file"; then
            echo "   - Hook already present. Skipping."
        else
            echo "   - Adding mise hook to $config_file..."
            # Append with a newline for safety
            echo "" >> "$config_file"
            echo "$activate_cmd" >> "$config_file"
        fi
    fi
}

# --- 3. Apply to Shells ---
# Update Bash
update_shell_config "$HOME/.bashrc" "bash"
update_shell_config "$HOME/.bash_profile" "bash"

# Update Zsh
update_shell_config "$HOME/.zshrc" "zsh"

# --- 4. Install Tools defined in mise.toml (Optional) ---
# If your repo has a mise.toml, this installs the tools immediately
if [ -f "./mise.toml" ]; then
    echo "⬇️  Installing tools from ./mise.toml..."
    "$MISE_BIN" install
fi

echo "🎉 Setup complete! Restart your terminal or run: source ~/.zshrc (or ~/.bashrc)"