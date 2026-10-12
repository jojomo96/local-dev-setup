# ──────────────────────────────────────────────────────────────────────────────
# Brewfile — the declarative list of everything Homebrew should install.
#
# THIS IS THE ALLOWLIST. `make brew` runs `brew bundle install --cleanup`,
# which installs everything here AND UNINSTALLS anything on the machine that is
# not here. That is how the garbage stays off the new laptop: you never
# migrate it, you just never list it.
#
# RULE: if a tool is in mise.toml, it must NOT be here.
#   mise owns: language runtimes + versioned CLIs (go, python, node, uv,
#              kubectl, helm, terraform, tflint, k9s, krew, jq, yq, awscli)
#   brew owns: GUI apps, fonts, system libs, zsh plugins, and anything mise
#              has no plugin for
# Duplicating a tool in both gives you two binaries and a PATH-order coin flip.
#
# This file is a STARTER, reconstructed from your old .zshrc. Run `make capture`
# on the current laptop BEFORE wiping it to generate Brewfile.audit from what
# you actually have, then move the keepers in here.
# ──────────────────────────────────────────────────────────────────────────────

# No taps needed: `brew bundle` is part of Homebrew core now, so the old
# `tap "homebrew/bundle"` line is obsolete.

# ══ CLI: core ════════════════════════════════════════════════════════════════
brew "git"
brew "git-lfs"
brew "gh"                 # GitHub CLI — also used for `gh auth login`
brew "coreutils"          # GNU versions; macOS ships ancient BSD tools
brew "curl"
brew "wget"
brew "openssh"
brew "gnupg"              # commit signing
brew "pinentry-mac"       # lets gpg prompt via the macOS keychain

# ══ CLI: shell experience ════════════════════════════════════════════════════
brew "zsh-syntax-highlighting"   # sourced by dotfiles/zsh/.zshrc
brew "zsh-autosuggestions"       # sourced by dotfiles/zsh/.zshrc
brew "kube-ps1"                  # cluster/namespace in prompt
brew "bat"                       # required by the zsh-bat omz plugin
brew "fzf"
brew "ripgrep"
brew "fd"
brew "eza"                       # modern ls
brew "zoxide"                    # smarter cd
brew "direnv"                    # per-project env vars
brew "tree"
brew "htop"
brew "watch"
brew "tmux"

# ══ CLI: dev ═════════════════════════════════════════════════════════════════
brew "make"
brew "cmake"
brew "shellcheck"         # CI lints this repo's scripts with it
brew "jd"                 # json diff
brew "mkcert"             # local TLS certs
# NOTE: httpie, pre-commit, ruff, black, mypy, ipython and ansible are Python
# tools and belong to uv — see uv-tools.list. Do not add them here.

# ══ Kubernetes: the bits mise doesn't version ════════════════════════════════
brew "kubectx"            # provides kubectx + kubens (aliased k x/kn)
brew "stern"              # multi-pod log tailing
brew "kustomize"

# ══ GUI apps ═════════════════════════════════════════════════════════════════
cask "docker-desktop"     # container runtime (consider `colima` as a lighter alt)
cask "visual-studio-code"
cask "goland"             # your Go IDE — JetBrains Toolbox also works
cask "jetbrains-toolbox"
cask "iterm2"
cask "rectangle"          # window snapping
cask "raycast"            # spotlight replacement
cask "keepassxc"          # password manager; ships keepassxc-cli for scripting

# ══ Fonts ════════════════════════════════════════════════════════════════════
cask "font-jetbrains-mono-nerd-font"   # nerd font: needed for powerline/k9s glyphs
cask "font-fira-code-nerd-font"

# ══ Mac App Store (needs `mas` + being signed in) ════════════════════════════
# brew "mas"
# mas "Xcode", id: 497799835
