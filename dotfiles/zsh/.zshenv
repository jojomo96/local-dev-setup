#!/usr/bin/env zsh
# ──────────────────────────────────────────────────────────────────────────────
# MANAGED BY local-dev-setup  (repo: dotfiles/zsh/.zshenv -> ~/.zshenv)
#
# .zshenv is sourced by EVERY zsh invocation, including non-interactive ones
# (scripts, IDE run configs, `ssh host cmd`, GUI apps launched from a shell).
# `mise activate` only runs in interactive shells, so non-interactive shells
# need the shim directory on PATH to see mise-managed tools at all.
#
# Keep this file minimal and side-effect free: no output, no prompts.
# ──────────────────────────────────────────────────────────────────────────────

# mise shims: makes kubectl/terraform/go/python resolve in non-interactive shells.
if [[ -d "$HOME/.local/share/mise/shims" ]]; then
  case ":$PATH:" in
    *":$HOME/.local/share/mise/shims:"*) ;;
    *) export PATH="$HOME/.local/share/mise/shims:$PATH" ;;
  esac
fi
