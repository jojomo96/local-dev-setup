#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# capture.sh — RUN THIS ON THE OLD LAPTOP, BEFORE YOU WIPE IT.
#
# Writes a snapshot of everything installed and configured into captured/.
# Nothing here is applied automatically; it exists so that after the reset you
# can diff what you had against what you declared, and so you notice the things
# that live outside any package manager.
#
# It also generates Brewfile.audit: your explicitly-installed brew packages,
# annotated with description and install date, so you can prune the garbage
# into a clean Brewfile instead of migrating it.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

OUT="$REPO_ROOT/captured"
mkdir -p "$OUT"

step "Capturing machine state to captured/"
info "This is read-only. Nothing is installed, removed, or changed."
echo

# ── Homebrew ────────────────────────────────────────────────────────────────
if have brew; then
  step "Homebrew"

  # Stop `brew` auto-updating mid-capture. It prints a few hundred lines of
  # "New Formulae"/"New Casks" announcing packages that are new in Homebrew's
  # repos — nothing to do with this machine — which buries the actual output.
  export HOMEBREW_NO_AUTO_UPDATE=1
  export HOMEBREW_NO_ENV_HINTS=1

  # --installed-on-request = things YOU asked for, not pulled in as deps.
  # This is the right audit input; `brew list` would bury you in dependencies.
  brew leaves --installed-on-request > "$OUT/brew-formulae.txt" 2>/dev/null \
    || brew leaves > "$OUT/brew-formulae.txt"
  brew list --cask > "$OUT/brew-casks.txt" 2>/dev/null || : > "$OUT/brew-casks.txt"
  brew tap > "$OUT/brew-taps.txt" 2>/dev/null || : > "$OUT/brew-taps.txt"

  # Full reference dump, dependencies included.
  brew bundle dump --file="$OUT/Brewfile.full" --force --describe 2>/dev/null || true

  local_formulae=$(wc -l < "$OUT/brew-formulae.txt" | tr -d ' ')
  local_casks=$(wc -l < "$OUT/brew-casks.txt" | tr -d ' ')
  ok "$local_formulae explicitly-installed formulae, $local_casks casks"

  # ── Annotated audit file ──────────────────────────────────────────────────
  step "Building Brewfile.audit (prune this into your Brewfile)"
  {
    echo "# ─────────────────────────────────────────────────────────────────"
    echo "# Brewfile.audit — generated $(date '+%Y-%m-%d %H:%M') by make capture"
    echo "#"
    echo "# Every line is COMMENTED OUT. Uncomment only what you actually want"
    echo "# on the new laptop, then move those lines into ./Brewfile."
    echo "# Anything you leave commented simply never gets installed again."
    echo "#"
    echo "# SIZE = disk footprint. Big + unfamiliar = probably garbage."
    echo "# Cross-check against mise.toml: do NOT keep brew copies of"
    echo "# kubectl/helm/terraform/go/python/node/jq/yq/awscli."
    echo "# ─────────────────────────────────────────────────────────────────"
    echo

    echo "# ══ FORMULAE (explicitly installed) ══"
    while read -r f; do
      [[ -z "$f" ]] && continue
      desc=$(brew desc --eval-all "$f" 2>/dev/null | head -1 | cut -c1-90 || echo "")
      size=$(du -sh "$(brew --prefix)/Cellar/$f" 2>/dev/null | cut -f1 || echo "?")
      printf '# brew "%s"%*s# [%s] %s\n' \
        "$f" $(( 34 - ${#f} > 1 ? 34 - ${#f} : 1 )) "" "${size:-?}" "${desc#* : }"
    done < "$OUT/brew-formulae.txt"

    echo
    echo "# ══ CASKS (GUI apps) ══"
    echo "# Cross-check against captured/app-usage.txt: an app you haven't"
    echo "# opened in a year is one you don't need on the new laptop."
    while read -r c; do
      [[ -z "$c" ]] && continue
      printf '# cask "%s"\n' "$c"
    done < "$OUT/brew-casks.txt"
  } > "$REPO_ROOT/Brewfile.audit"
  ok "wrote Brewfile.audit — open it and uncomment the keepers"

  # ── When did you last actually open these apps? ───────────────────────────
  # The honest answer to "do I still need this". Spotlight tracks last-used
  # dates; oldest first, so the dead weight floats to the top.
  step "App usage dates (the real test for 'do I still use this?')"
  {
    echo "# Applications by last-used date, OLDEST FIRST."
    echo "# Anything at the top you haven't touched in months: don't reinstall it."
    echo "# '-' means Spotlight has no record of it ever being opened."
    echo
    for app in /Applications/*.app; do
      [[ -e "$app" ]] || continue
      used="$(mdls -raw -name kMDItemLastUsedDate "$app" 2>/dev/null)"
      [[ -z "$used" || "$used" == "(null)" ]] && used="-"
      printf '%s\t%s\n' "${used:0:10}" "$(basename "$app" .app)"
    done | sort
  } > "$OUT/app-usage.txt"
  ok "captured/app-usage.txt"
else
  warn "brew not found — skipping Homebrew capture"
fi

# ── Everything else that lives outside brew ─────────────────────────────────
step "Other package managers and tool registries"

dump() {
  local name="$1" file="$2"; shift 2
  if have "$1"; then
    if "$@" > "$OUT/$file" 2>/dev/null; then
      ok "$name -> captured/$file"
    else
      rm -f "$OUT/$file"; warn "$name: command failed, skipped"
    fi
  fi
}

dump "mise tools"       "mise-tools.txt"      mise ls --current
dump "uv tools"         "uv-tools.txt"        uv tool list
dump "pipx"             "pipx.txt"            pipx list --short
dump "npm globals"      "npm-global.txt"      npm ls -g --depth=0
dump "pnpm globals"     "pnpm-global.txt"     pnpm ls -g --depth=0
dump "cargo installs"   "cargo.txt"           cargo install --list
dump "go binaries"      "go-bins.txt"         ls -1 "${GOPATH:-$HOME/go}/bin"
dump "krew plugins"     "krew-plugins.txt"    kubectl krew list
dump "helm repos"       "helm-repos.txt"      helm repo list
dump "VS Code exts"     "vscode-extensions.txt" code --list-extensions
dump "oh-my-zsh custom" "omz-custom.txt"      ls -1 "$HOME/.oh-my-zsh/custom/plugins"

# ── Config files worth copying by hand ──────────────────────────────────────
step "Config inventory (paths only — contents may hold secrets)"
{
  echo "# Files/dirs present on the old machine that are NOT managed by this repo."
  echo "# Review each one and decide: re-create, migrate, or abandon."
  echo "# Generated $(date '+%Y-%m-%d %H:%M')"
  echo
  for p in \
    ~/.ssh ~/.gnupg ~/.aws ~/.kube ~/.config/stackit ~/.docker ~/.netrc \
    ~/.npmrc ~/.pypirc ~/.terraformrc ~/.terraform.d ~/.cargo ~/.nvm \
    ~/.zshrc.local ~/.gitconfig ~/.config/gh ~/Library/LaunchAgents \
    ~/.local/share/mise ~/.oh-my-zsh/custom /etc/hosts
  do
    if [[ -e "$p" ]]; then
      size=$(du -sh "$p" 2>/dev/null | cut -f1 || echo "?")
      printf '%-34s EXISTS  (%s)\n' "$(pretty_path "$p")" "$size"
    else
      printf '%-34s -\n' "$(pretty_path "$p")"
    fi
  done
} > "$OUT/config-inventory.txt"
ok "captured/config-inventory.txt"

# ── Dotfiles: what could this repo be managing that it isn't? ───────────────
step "Dotfile inventory (what's managed vs. what's loose)"
{
  echo "# Dotfiles on this machine, grouped by what you should do with them."
  echo "# Generated $(date '+%Y-%m-%d %H:%M')"
  echo

  echo "## ALREADY MANAGED by this repo (symlinks into the repo)"
  for p in ~/.zshrc ~/.zshenv ~/.gitconfig ~/.gitignore_global \
           ~/.config/mise/config.toml; do
    if [[ -L "$p" ]]; then
      printf '  %-34s -> %s\n' "$(pretty_path "$p")" "$(readlink "$p")"
    elif [[ -e "$p" ]]; then
      printf '  %-34s %s\n' "$(pretty_path "$p")" "EXISTS BUT NOT A SYMLINK (run make dotfiles)"
    fi
  done

  echo
  echo "## CANDIDATES — plain config, safe to move into dotfiles/ and version"
  for p in ~/.tmux.conf ~/.ripgreprc ~/.editorconfig ~/.inputrc ~/.vimrc \
           ~/.config/bat/config ~/.config/direnv/direnvrc ~/.config/k9s \
           ~/.config/nvim ~/.config/gh/config.yml ~/.terraformrc \
           ~/.oh-my-zsh/custom ~/.zprofile ~/.zshrc.local \
           "$HOME/Library/Application Support/Code/User/settings.json" \
           "$HOME/Library/Application Support/Code/User/keybindings.json"; do
    [[ -e "$p" ]] && printf '  %-44s (%s)\n' "$(pretty_path "$p")" \
      "$(du -sh "$p" 2>/dev/null | cut -f1)"
  done

  echo
  echo "## DO NOT VERSION — these contain credentials or machine state"
  for p in ~/.ssh/config ~/.netrc ~/.npmrc ~/.pypirc ~/.docker/config.json \
           ~/.config/gh/hosts.yml ~/.aws ~/.kube ~/.config/stackit \
           ~/.terraform.d/credentials.tfrc.json; do
    [[ -e "$p" ]] && printf '  %-44s (%s)\n' "$(pretty_path "$p")" \
      "$(du -sh "$p" 2>/dev/null | cut -f1)"
  done

  echo
  echo "## EVERYTHING ELSE in \$HOME (top level, for anything missed above)"
  find "$HOME" -maxdepth 1 -name '.*' \( -type f -o -type l \) 2>/dev/null \
    | sort | while read -r p; do printf '  %s\n' "$(pretty_path "$p")"; done
} > "$OUT/dotfiles-inventory.txt"
ok "captured/dotfiles-inventory.txt"

# ── Repos with uncommitted work: the classic data-loss trap ─────────────────
step "Scanning for git repos with uncommitted or unpushed work"
info "(searching ~ to depth 5, this can take a minute)"
{
  echo "# Git repos with changes that exist ONLY on this laptop."
  echo "# Commit and push every one of these before you wipe."
  echo
  while IFS= read -r gitdir; do
    repo="$(dirname "$gitdir")"
    dirty=""
    [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]] && dirty="UNCOMMITTED"
    if git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
      [[ -n "$(git -C "$repo" log '@{u}..HEAD' --oneline 2>/dev/null)" ]] \
        && dirty="${dirty:+$dirty+}UNPUSHED"
    else
      dirty="${dirty:+$dirty+}NO-REMOTE"
    fi
    [[ -n "$dirty" ]] && printf '%-12s %s\n' "$dirty" "$(pretty_path "$repo")"
  done < <(find "$HOME" -maxdepth 5 -type d -name .git -not -path '*/node_modules/*' 2>/dev/null)
} > "$OUT/dirty-repos.txt"
dirty_count=$(grep -c . < <(grep -v '^#' "$OUT/dirty-repos.txt" | grep .) || true)
if [[ "${dirty_count:-0}" -gt 0 ]]; then
  warn "$dirty_count repos have local-only work — see captured/dirty-repos.txt"
else
  ok "no repos with local-only work found"
fi

echo
step "Capture complete"
info "Next:"
info "  1. Open ${BOLD}Brewfile.audit${RESET} and uncomment what you want to keep"
info "  2. Move those lines into ${BOLD}Brewfile${RESET}, delete the audit file"
info "  3. Work through ${BOLD}RESET-CHECKLIST.md${RESET}"
info "  4. ${BOLD}git add -A && git commit && git push${RESET} — then wipe"
echo
warn "captured/ is gitignored by default: it lists your private paths."
warn "Do NOT commit captured/Brewfile.full blindly if you review it later."
