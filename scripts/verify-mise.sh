#!/usr/bin/env bash
set -euo pipefail

# Load shared helpers (colors, etc.)
# shellcheck source=./common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Verifies that mise is installed.
# Checks PATH first, then falls back to the default install location used by our setup script.

DEFAULT_MISE_BIN="$HOME/.local/bin/mise"


if command -v mise >/dev/null 2>&1; then
  MISE_PATH="$(command -v mise)"
  echo "${GREEN}mise is installed: ${MISE_PATH}${RESET}"
  exit 0
fi

if [ -x "$DEFAULT_MISE_BIN" ]; then
  echo "${GREEN}mise is installed: ${DEFAULT_MISE_BIN}${RESET}"
  exit 0
fi

echo "${YELLOW}mise is not installed.${RESET}"
echo "${YELLOW}Run: make install${RESET}"
exit 1
