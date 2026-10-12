#!/usr/bin/env zsh
# ──────────────────────────────────────────────────────────────────────────────
# MANAGED BY local-dev-setup
#
# This file lives in the repo at dotfiles/zsh/.zshrc and is symlinked to
# ~/.zshrc by `make bootstrap`. Edit it IN THE REPO and commit.
#
# Machine-specific tweaks  ->  ~/.zshrc.local   (not managed, sourced at the end)
# Secrets / credentials    ->  ~/.config/devsetup/secrets.env  (chmod 600)
# ──────────────────────────────────────────────────────────────────────────────

# --- Homebrew ----------------------------------------------------------------
# Must come first: everything below may rely on brew-installed tools.
# Sets HOMEBREW_PREFIX, PATH, MANPATH.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"        # Apple Silicon
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"           # Intel
fi

# --- History -----------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt SHARE_HISTORY INC_APPEND_HISTORY

# --- oh-my-zsh ---------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
zstyle ':omz:update' mode reminder

# Keep this list lean: every plugin costs shell startup time.
# zsh-bat is a third-party plugin; bootstrap.sh clones it into $ZSH_CUSTOM.
plugins=(
  git
  terraform
  golang
  brew
  docker
  docker-compose
  python
  zsh-bat
)
[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# --- PATH --------------------------------------------------------------------
# ~/.local/bin holds mise itself and uv-installed tool shims.
export PATH="$HOME/.local/bin:$PATH"
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# pnpm (installed via corepack/mise node, home dir is macOS-specific)
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# GNU coreutils ahead of the BSD tools macOS ships, so ls/date/sed/readlink
# behave the way they do everywhere else. Requires brew "coreutils".
# Deliberately placed before the mise activation below, so mise's shims still
# win for anything it manages.
if [[ -d "$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin" ]]; then
  export PATH="$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin:$PATH"
  export MANPATH="$HOMEBREW_PREFIX/opt/coreutils/libexec/gnuman:${MANPATH:-}"
fi

# --- Environment -------------------------------------------------------------
export LANG="en_US.UTF-8"
export EDITOR="${EDITOR:-code --wait}"
export VISUAL="$EDITOR"
export PAGER="less"

# Required on macOS: Python/Ansible fork after Objective-C runtime init.
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# --- Kubernetes --------------------------------------------------------------
# Build KUBECONFIG by discovery rather than hardcoding cluster filenames
# (those change per project and break after a laptop reset).
#
# Covers both layouts: configs directly in ~/.kube, and the ~/.kube/configs/
# subdirectory. NOT a blind recursive glob — ~/.kube/cache and
# ~/.kube/http-cache are full of .json discovery documents that would
# otherwise end up in KUBECONFIG and break kubectl.
if [[ -d "$HOME/.kube" ]]; then
  typeset -a _kubeconfigs
  _kubeconfigs=(
    "$HOME"/.kube/*.(yml|yaml|json)(N)
    "$HOME"/.kube/configs/**/*.(yml|yaml|json)(N)
  )
  (( ${#_kubeconfigs} )) && export KUBECONFIG="${(j|:|)_kubeconfigs}"
  unset _kubeconfigs
fi

# kube-ps1: show current cluster/namespace in the prompt.
if [[ -r "$HOMEBREW_PREFIX/opt/kube-ps1/share/kube-ps1.sh" ]]; then
  source "$HOMEBREW_PREFIX/opt/kube-ps1/share/kube-ps1.sh"
  PS1='$(kube_ps1)'"$PS1"
fi

# --- Aliases -----------------------------------------------------------------
alias stackit="stackit-cli"
alias k="kubectl"
alias kx="kubectx"
alias kn="kubens"
alias tf="terraform"

# --- Functions ---------------------------------------------------------------

# Copy all file contents in a directory (default: current dir) to the clipboard.
catall() {
  local dir="${1:-.}"
  for f in "$dir"/*; do
    [[ -f "$f" ]] || continue
    echo "----- FILE: $f -----"
    cat "$f"
    echo
  done | pbcopy
  echo "📋 All file contents from $dir copied to clipboard."
}

# Run the cs-toolbox privilege escalation helper.
# Override the checkout location with CS_TOOLBOX_ROOT in ~/.zshrc.local.
kubectl-escalate() {
  local proj_dir="${CS_TOOLBOX_ROOT:-$HOME/GolandProjects/cs-toolbox}/k8s/escalate-privileges"
  if [[ ! -d "$proj_dir" ]]; then
    echo "cs-toolbox not found at $proj_dir (set CS_TOOLBOX_ROOT)" >&2
    return 1
  fi
  # `go -C` runs from the module directory so go.mod resolves. Passing an
  # absolute path to `go run` instead fails once the file has imports.
  go -C "$proj_dir" run kubectl-escalate.go "$@"
}

# --- Tool activation ---------------------------------------------------------
# mise: manages language runtimes and CLI tool versions (see mise.toml).
if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh)"
fi

# direnv: per-project env vars from .envrc
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# zoxide: smarter cd
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# fzf: Ctrl-R / Ctrl-T fuzzy search
[[ -r "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ]] \
  && source "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
[[ -r "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" ]] \
  && source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh"

# --- Secrets -----------------------------------------------------------------
# Credentials are NEVER stored in this repo. Copy secrets.env.example to
# ~/.config/devsetup/secrets.env and fill it in (chmod 600).
[[ -r "$HOME/.config/devsetup/secrets.env" ]] \
  && source "$HOME/.config/devsetup/secrets.env"

# --- Machine-local overrides -------------------------------------------------
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# --- Must stay last ----------------------------------------------------------
# zsh-autosuggestions before zsh-syntax-highlighting; highlighting wraps the
# ZLE widgets and must see the final state.
[[ -r "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] \
  && source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -r "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] \
  && source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
