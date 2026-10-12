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

# `brew bundle` is part of Homebrew core now, so the old `tap "homebrew/bundle"`
# line is obsolete. This tap is required for the tap-qualified gcx formula below.
tap "grafana/grafana"

# ══ CLI: core ════════════════════════════════════════════════════════════════
brew "git"
brew "git-lfs"
brew "gh"                 # GitHub CLI — also used for `gh auth login`
brew "coreutils"          # GNU versions; macOS ships ancient BSD tools
brew "gnu-tar"            # same reason: BSD tar differs in flags and output
brew "curl"
brew "wget"
brew "openssh"            # required for FIDO2 hardware keys — see note below
# gnupg + pinentry-mac are NOT installed: commit signing here uses an SSH key
# (git's gpg.format=ssh), so there's no GPG keyring to manage. Uncomment only
# if you need GPG for something else, e.g. verifying release signatures.
# brew "gnupg"
# brew "pinentry-mac"

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
brew "shellcheck"         # CI lints this repo's scripts with it
brew "jd"                 # json diff
brew "mkcert"             # local TLS certs
# brew "wireshark"        # tshark CLI; pairs with the wireshark-app cask
# brew "gemini-cli"       # 430M — largest formula on the old laptop
brew "ipcalc"             # subnet maths
brew "git-quick-stats"    # repo contribution summaries
brew "nano"               # newer than the nano macOS ships
brew "sql-migrate"        # Go database migrations
# cmake/glm/glfw/nasm removed: that was the Vulkan toolchain, no longer needed.
# golangci-lint is in mise.toml so it tracks the Go version — not here.
# Dropped as leftovers: fish, pipx, brew-cask-completion, s3cmd, snyk-cli,
# cocoapods. Dropped as mise duplicates: helm, k9s, krew, tflint,
# terraform-docs, yq, python@3.12.

# ══ Observability ════════════════════════════════════════════════════════════
brew "grizzly"                  # Grafana dashboards-as-code
brew "grafana/grafana/gcx"      # Grafana Cloud exporter (needs the tap above)
# thanos (89M) left out — it's a Prometheus server component rather than a
# laptop CLI. Uncomment if you actually query it locally.
# brew "thanos"
# NOTE: httpie, pre-commit, ruff, black, mypy, ipython and ansible are Python
# tools and belong to uv — see uv-tools.list. Do not add them here.

# ══ Kubernetes: the bits mise doesn't version ════════════════════════════════
brew "kubectx"            # provides kubectx + kubens (aliased k x/kn)
brew "stern"              # multi-pod log tailing
brew "kustomize"

# ══ GUI apps ═════════════════════════════════════════════════════════════════
# Confirmed present on the old laptop:
cask "iterm2"
cask "raycast"            # spotlight replacement
cask "alt-tab"            # Windows-style window switcher
cask "jordanbaird-ice"    # menu bar manager
cask "grandperspective"   # visual disk usage
cask "spotify"
cask "thunderbird"
cask "gcloud-cli"         # Google Cloud CLI
cask "proxy-audio-device" # virtual audio device for routing/recording
# Rectangle is deliberately NOT here: your company's MDM installs it. Listing
# it would make brew install a second copy, and `brew bundle --cleanup` would
# then fight the MDM over which one owns /Applications/Rectangle.app.
# Its *settings* are still managed — see macos_pref_domains in group_vars.

# ── Undecided: uncomment what you want ──────────────────────────────────────
# These are the heavy ones. Nothing installs them while they're commented.
# cask "mactex"           # multi-GB full LaTeX; `basictex` is far smaller
# cask "wireshark-app"    # GUI; also needs brew "wireshark" (122M) for tshark
# cask "headlamp"         # K8s GUI — k9s (via mise) covers the same job
#
# Dropped: flutter (no more mobile dev), lidanglesensor.

# Added by this setup:
cask "keepassxc"          # password manager; ships keepassxc-cli for scripting
cask "secretive"          # SSH keys in the Secure Enclave, gated by Touch ID
# NOTE: brew "openssh" above is required for FIDO2/hardware keys (Token2,
# YubiKey) — Apple's /usr/bin/ssh is built without libfido2, so
# `ssh-keygen -t ed25519-sk` fails with it.

# NOT listed, because your old laptop had no cask for them — if these came
# from your company's MDM or JetBrains Toolbox, leave them out; if you
# installed them by hand, uncomment:
# cask "docker-desktop"
# cask "visual-studio-code"
# cask "goland"
# cask "jetbrains-toolbox"
# cask "rectangle"        # window snapping (alt-tab covers switching, not snapping)
# NOTE: brew "openssh" above is required for FIDO2/hardware keys (Token2,
# YubiKey) — Apple's /usr/bin/ssh is built without libfido2, so
# `ssh-keygen -t ed25519-sk` fails with it.

# ══ Fonts ════════════════════════════════════════════════════════════════════
# This is the font actually installed on the old laptop; the jetbrains-mono and
# fira-code nerd fonts previously listed here were guesses.
cask "font-caskaydia-cove-nerd-font"

# ══ Mac App Store (needs `mas` + being signed in) ════════════════════════════
# brew "mas"
# mas "Xcode", id: 497799835
