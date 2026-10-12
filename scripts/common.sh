#!/usr/bin/env bash
# Shared helpers for scripts in this repo. Source, don't execute.

# shellcheck disable=SC2034
init_colors() {
  if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" ]]; then
    RED=$(tput setaf 1 2>/dev/null || echo "")
    GREEN=$(tput setaf 2 2>/dev/null || echo "")
    YELLOW=$(tput setaf 3 2>/dev/null || echo "")
    BLUE=$(tput setaf 4 2>/dev/null || echo "")
    WHITE=$(tput setaf 7 2>/dev/null || echo "")
    BOLD=$(tput bold 2>/dev/null || echo "")
    RESET=$(tput sgr0 2>/dev/null || echo "")
  else
    RED="" GREEN="" YELLOW="" BLUE="" WHITE="" BOLD="" RESET=""
  fi
}
init_colors

# Repo root, resolved from this file's location so scripts work from any cwd.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

step()  { echo "${BLUE}${BOLD}==>${RESET} ${BOLD}$*${RESET}"; }
info()  { echo "    $*"; }
ok()    { echo "    ${GREEN}✓${RESET} $*"; }
warn()  { echo "    ${YELLOW}!${RESET} $*"; }
fail()  { echo "    ${RED}✗${RESET} $*"; }
die()   { fail "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

# Shorten a path for display: /Users/you/.zshrc -> ~/.zshrc
# Done with a case glob rather than ${p/#$HOME/~}, which does not reliably
# substitute (the pattern is parsed before $HOME expands).
pretty_path() {
  case "$1" in
    "$HOME"/*) printf '~%s\n' "${1#"$HOME"}" ;;
    "$HOME")   printf '~\n' ;;
    *)         printf '%s\n' "$1" ;;
  esac
}

# Octal permission bits of a file. stat(1) flags differ between BSD and GNU:
# `stat -f` means "filesystem info" on GNU, so it must not be used as a fallback.
file_mode() {
  if is_macos; then
    stat -f '%Lp' "$1" 2>/dev/null
  else
    stat -c '%a' "$1" 2>/dev/null
  fi
}

# Ask a yes/no question. Honours ASSUME_YES=1 for unattended runs (CI, tests).
confirm() {
  local prompt="$1"
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    info "$prompt ${YELLOW}[auto-yes]${RESET}"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    warn "$prompt — no TTY, assuming no"
    return 1
  fi
  local reply
  read -r -p "    ${BOLD}?${RESET} $prompt [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# Timestamped backup of a path. Never clobbers a previous backup.
# Returns silently if the path does not exist.
backup_path() {
  local target="$1"
  [[ -e "$target" || -L "$target" ]] || return 0
  local stamp backup
  stamp="$(date +%Y%m%d-%H%M%S)"
  backup="${target}.bak.${stamp}"
  mv "$target" "$backup"
  warn "backed up existing $(basename "$target") -> $(basename "$backup")"
}
