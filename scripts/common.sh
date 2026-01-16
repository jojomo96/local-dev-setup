#!/usr/bin/env bash

# Shared helpers for scripts in this repo.

# shellcheck disable=SC2034
init_colors() {
  # Define colors (fallback to empty strings if tput isn't available)
  if command -v tput >/dev/null 2>&1; then
    GREEN=$(tput -Txterm setaf 2)
    YELLOW=$(tput -Txterm setaf 3)
    WHITE=$(tput -Txterm setaf 7)
    RESET=$(tput -Txterm sgr0)
  else
    GREEN=""
    YELLOW=""
    WHITE=""
    RESET=""
  fi
}

# Default: initialize colors on source.
init_colors
