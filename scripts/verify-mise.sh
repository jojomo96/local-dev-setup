#!/usr/bin/env bash
set -euo pipefail

# Verifies that mise is installed.
# Checks PATH first, then falls back to the default install location used by our setup script.

DEFAULT_MISE_BIN="$HOME/.local/bin/mise"

echo "🔎 Verifying mise installation..."

if command -v mise >/dev/null 2>&1; then
  MISE_PATH="$(command -v mise)"
  echo "✅ mise is installed: ${MISE_PATH}"
  exit 0
fi

if [ -x "$DEFAULT_MISE_BIN" ]; then
  echo "✅ mise is installed: ${DEFAULT_MISE_BIN}"
  exit 0
fi

echo "❌ mise is not installed."
echo "   Run: make install"
exit 1
