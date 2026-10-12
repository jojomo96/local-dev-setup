#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# check-duplicates.sh — enforce "one tool, one manager".
#
# A tool declared in two managers means two binaries on PATH and a coin flip
# over which one you get, with different versions. It is the single most common
# way a setup like this quietly rots. Run in CI and by `make doctor`.
#
# Parses the declaration files only — does not require the tools to be installed,
# so it runs anywhere.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

BREWFILE="$REPO_ROOT/Brewfile"
MISEFILE="$REPO_ROOT/mise.toml"
UVFILE="$REPO_ROOT/uv-tools.list"

# brew formula/cask names, ignoring comments and trailing inline comments.
brew_names() {
  [[ -f "$BREWFILE" ]] || return 0
  sed 's/#.*//' "$BREWFILE" \
    | grep -oE '^(brew|cask)[[:space:]]+"[^"]+"' \
    | grep -oE '"[^"]+"' | tr -d '"'
}

# mise tool names from the [tools] table. Strips the `go:github.com/...`
# backend prefix down to the resulting binary-ish name.
mise_names() {
  [[ -f "$MISEFILE" ]] || return 0
  awk '
    /^\[tools\]/      { in_tools = 1; next }
    /^\[/             { in_tools = 0 }
    in_tools && /=/   {
      sub(/#.*/, "")
      split($0, a, "=")
      name = a[1]
      gsub(/[[:space:]"]/, "", name)
      if (name != "") print name
    }
  ' "$MISEFILE" | sed 's#.*/##'
}

# uv tool names: first token of each entry, flags and comments dropped.
uv_names() {
  [[ -f "$UVFILE" ]] || return 0
  sed 's/#.*//' "$UVFILE" | awk 'NF { print $1 }'
}

overlap() {
  local a_label="$1" b_label="$2" a_fn="$3" b_fn="$4"
  local found=0
  # comm needs sorted input; process substitution keeps it to one pass.
  while IFS= read -r dup; do
    [[ -z "$dup" ]] && continue
    fail "'$dup' is declared in BOTH $a_label and $b_label"
    found=1
  done < <(comm -12 <("$a_fn" | sort -u) <("$b_fn" | sort -u))
  return $found
}

step "Checking for tools declared in more than one manager"

STATUS=0
overlap "Brewfile" "mise.toml"     brew_names mise_names || STATUS=1
overlap "Brewfile" "uv-tools.list" brew_names uv_names   || STATUS=1
overlap "mise.toml" "uv-tools.list" mise_names uv_names  || STATUS=1

if (( STATUS == 0 )); then
  ok "no duplicates across Brewfile, mise.toml and uv-tools.list"
else
  echo
  info "Fix: decide which manager owns the tool and remove the other entry."
  info "  mise -> language runtimes and versioned CLIs"
  info "  brew -> GUI apps, fonts, system libs, zsh plugins"
  info "  uv   -> Python CLI tools"
fi
exit $STATUS
