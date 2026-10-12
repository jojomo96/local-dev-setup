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

# HTTPS, not SSH: this must clone on a freshly wiped machine that has no keys
# and no GitHub auth yet. That works only while the repo is PUBLIC — if you
# make it private, this clone fails and you'll need to authenticate first.
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

# ── 3. Ansible, in a throwaway venv ────────────────────────────────────────
# Why a venv and not `pip install --user`:
#   - venv is in the standard library, so there is nothing to install first
#     (pipx would itself need pip --user, moving the problem one layer down)
#   - the binary lives at a known absolute path, so no guessing at
#     ~/Library/Python/<version>/bin, whose version varies by macOS release
#   - it cannot collide with any other Python tool's dependencies
#   - deleting one directory removes it completely
#
# Homebrew and mise don't exist yet — the playbook installs them — so the
# system python3 from the Xcode CLT is all we have to work with. That's fine:
# this venv only has to live long enough to run the playbook once. After that,
# uv-tools.list installs ansible-core properly into ~/.local/bin and the
# Makefile prefers that copy.
VENV="$HOME/.local/share/devsetup/bootstrap-venv"
ANSIBLE="$VENV/bin/ansible-playbook"
GALAXY="$VENV/bin/ansible-galaxy"

# Prefer an already-installed Ansible (uv-managed, from a previous run).
if command -v ansible-playbook >/dev/null 2>&1; then
  ANSIBLE="$(command -v ansible-playbook)"
  GALAXY="$(command -v ansible-galaxy)"
  say "Using existing $("$ANSIBLE" --version | head -1)"
elif [[ -x "$ANSIBLE" ]]; then
  say "Using bootstrap venv: $("$ANSIBLE" --version | head -1)"
else
  command -v python3 >/dev/null || die "python3 not found (Xcode CLT provides it)"
  say "Creating a bootstrap venv for Ansible"
  echo "    $VENV"
  mkdir -p "$(dirname "$VENV")"
  python3 -m venv "$VENV"
  "$VENV/bin/python" -m pip install --quiet --upgrade pip
  "$VENV/bin/python" -m pip install --quiet ansible-core
  say "Installed $("$ANSIBLE" --version | head -1)"
fi

[[ -x "$ANSIBLE" ]] || die "ansible-playbook not usable at $ANSIBLE"

# ── 4. Collections ──────────────────────────────────────────────────────────
# ansible.cfg sets collections_path=./collections, so these land in the repo
# and are shared by whichever ansible binary runs later.
say "Installing Ansible collections"
"$GALAXY" install -r requirements.yml

# ── 5. Hand over to the playbook ────────────────────────────────────────────
say "Running the playbook"
echo "    Everything from here is declarative and re-runnable."
echo

# --ask-become-pass only when a task actually needs root. Nothing currently
# does, so this stays unprivileged; add --ask-become-pass if that changes.
"$ANSIBLE" main.yml "$@"

# ── 6. Point at the permanent install ──────────────────────────────────────
if [[ "$ANSIBLE" == "$VENV/bin/ansible-playbook" ]] \
  && [[ -x "$HOME/.local/bin/ansible-playbook" ]]; then
  say "Bootstrap venv no longer needed"
  echo "    uv has installed Ansible to ~/.local/bin (see uv-tools.list)."
  echo "    Remove the bootstrap copy with: make clean-venv"
fi
