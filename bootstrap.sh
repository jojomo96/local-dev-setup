#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# bootstrap.sh — the only imperative code in this repo.
#
# Ansible can't configure a machine that doesn't have Ansible, so this shim
# gets Python + Ansible in place and then hands over to the playbook. It does
# as little as possible on purpose.
#
# Run on a freshly reset laptop:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jojomo96/local-dev-setup/main/bootstrap.sh)"
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_URL="https://github.com/jojomo96/local-dev-setup.git"
CLONE_DIR="${DEVSETUP_DIR:-$HOME/local-dev-setup}"

say()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '    \033[1;33m!\033[0m %s\n' "$*"; }
die()  { printf '    \033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# ── 1. Xcode Command Line Tools (gives us git and python3) ──────────────────
if [[ "$(uname -s)" == "Darwin" ]]; then
  if ! xcode-select -p >/dev/null 2>&1; then
    say "Installing Xcode Command Line Tools"
    xcode-select --install 2>/dev/null || true
    warn "Accept the GUI installer, wait for it to finish, then re-run this."
    exit 1
  fi
fi

command -v git >/dev/null || die "git not found and Xcode CLT is installed — unexpected."

# ── 2. Get the repo ─────────────────────────────────────────────────────────
# When curl-piped, $0 isn't a file in the repo, so clone first and re-exec.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")" 2>/dev/null && pwd || echo "")"
if [[ -z "$SELF_DIR" || ! -f "$SELF_DIR/main.yml" ]]; then
  say "Fetching the setup repo"
  if [[ -d "$CLONE_DIR/.git" ]]; then
    git -C "$CLONE_DIR" pull --ff-only
  else
    git clone "$REPO_URL" "$CLONE_DIR"
  fi
  exec /bin/bash "$CLONE_DIR/bootstrap.sh" "$@"
fi
cd "$SELF_DIR"

# ── 3. Ansible ──────────────────────────────────────────────────────────────
# Installed via pip --user rather than Homebrew: this must work before brew
# exists, and the playbook itself is what installs Homebrew.
if ! command -v ansible-playbook >/dev/null 2>&1; then
  export PATH="$HOME/Library/Python/3.9/bin:$HOME/.local/bin:$PATH"
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  say "Installing Ansible"
  python3 -m pip install --user --quiet --upgrade pip
  python3 -m pip install --user --quiet ansible-core
  export PATH="$HOME/Library/Python/3.9/bin:$HOME/.local/bin:$PATH"
fi

command -v ansible-playbook >/dev/null \
  || die "ansible-playbook still not on PATH. Add ~/.local/bin and retry."

say "Using $(ansible-playbook --version | head -1)"

# ── 4. Collections ──────────────────────────────────────────────────────────
say "Installing Ansible collections"
ansible-galaxy install -r requirements.yml

# ── 5. Hand over to the playbook ────────────────────────────────────────────
say "Running the playbook"
echo "    Everything from here is declarative and re-runnable."
echo

# --ask-become-pass only when a task actually needs root. Nothing currently
# does, so this stays unprivileged; add --ask-become-pass if that changes.
exec ansible-playbook main.yml "$@"
