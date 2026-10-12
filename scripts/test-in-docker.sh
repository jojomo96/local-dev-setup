#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# test-in-docker.sh — run the playbook in a throwaway Linux container.
#
# The headline assertion is idempotency: Ansible's own recap must report
# changed=0 on the second run. That is a machine-checked guarantee across every
# task, which is strictly stronger than the hand-written assertions this
# replaced — and it's the property that matters, because a setup you can't
# safely re-run is a setup you can't trust on reset day.
#
# Limitations, stated plainly: this is Linux, so the Homebrew and macOS
# preference tasks are skipped. CI runs the same playbook on macos-latest.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

have docker || die "docker not found — this target needs a container runtime"

IMAGE="local-dev-setup-test"

step "Building test image"
docker build -t "$IMAGE" -f - "$REPO_ROOT" <<'DOCKERFILE'
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates git zsh make file procps \
      python3 python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Ansible is deliberately NOT preinstalled. The point is to exercise the real
# bootstrap path: bootstrap.sh must build its own venv from the system python,
# exactly as it will on a freshly wiped laptop.

RUN useradd -m -s /bin/zsh tester
USER tester
WORKDIR /home/tester/local-dev-setup
COPY --chown=tester:tester . .
DOCKERFILE

step "Running the playbook twice"
info "Homebrew and macOS tasks are skipped (Linux)."
echo

# mise resolves tool versions through the GitHub API: 60 requests/hour per IP
# unauthenticated, which a full install can exhaust — and re-running the test a
# few times certainly will. Pass a token through if one is available; `gh auth
# token` works if you're logged in. Any token will do, no scopes needed.
GH_TOKEN_VALUE="${GITHUB_TOKEN:-$(gh auth token 2>/dev/null || echo "")}"
if [[ -z "$GH_TOKEN_VALUE" ]]; then
  warn "No GITHUB_TOKEN and no gh login — mise will make unauthenticated"
  warn "GitHub API calls (60/hour). If this fails with a 403 rate limit, set"
  warn "GITHUB_TOKEN and re-run; it is not a problem with the playbook."
fi

docker run --rm -i -e GITHUB_TOKEN="$GH_TOKEN_VALUE" "$IMAGE" bash -lc '
    set -euo pipefail
    export PATH="$HOME/.local/bin:$PATH"
    export ANSIBLE_FORCE_COLOR=1

    EXTRA="-e configure_homebrew=false -e configure_macos=false \
           -e git_user_name=Test -e git_user_email=test@example.com"

    echo "───── run 1: bootstrap.sh from a bare machine ─────"
    # No ansible on PATH: this must create the venv and install it itself.
    ./bootstrap.sh $EXTRA

    echo
    echo "───── asserting the bootstrap venv was created ─────"
    VENV="$HOME/.local/share/devsetup/bootstrap-venv"
    [ -x "$VENV/bin/ansible-playbook" ] \
      || { echo "  FAIL bootstrap venv missing at $VENV"; exit 1; }
    echo "  ok   venv at $VENV"

    # Resolve ansible the same way the Makefile does: prefer the uv-installed
    # copy, fall back to the bootstrap venv.
    AP="$HOME/.local/bin/ansible-playbook"
    [ -x "$AP" ] || AP="$VENV/bin/ansible-playbook"
    echo "  using $AP"

    echo
    echo "───── syntax check ─────"
    "$AP" main.yml --syntax-check

    echo
    echo "───── run 2: must report changed=0 ─────"
    "$AP" main.yml $EXTRA | tee /tmp/run2.log

    echo
    echo "───── asserting idempotency ─────"
    # Strip ANSI codes first: ANSIBLE_FORCE_COLOR makes the recap line start
    # with an escape sequence, so "^localhost" silently never matches and the
    # assertion reports an empty recap instead of a real result.
    recap=$(sed -e "s/\x1b\[[0-9;]*m//g" /tmp/run2.log | grep -E "^localhost +:" || true)
    if [ -z "$recap" ]; then
      echo "  FAIL could not find the PLAY RECAP line — assertion is broken"
      exit 1
    fi
    echo "  recap: $recap"
    if ! echo "$recap" | grep -q "changed=0"; then
      echo "  FAIL second run was not idempotent"
      echo "  Tasks that changed on the second run:"
      sed -e "s/\x1b\[[0-9;]*m//g" /tmp/run2.log \
        | grep -B1 "^changed:" | grep "^TASK" || true
      exit 1
    fi
    echo "  ok   second run changed nothing"

    echo
    echo "───── asserting symlinks point into the repo ─────"
    for f in .zshrc .zshenv .gitconfig .gitignore_global; do
      target=$(readlink "$HOME/$f" || echo "NOT-A-LINK")
      case "$target" in
        *"/local-dev-setup/"*) echo "  ok   $f -> $target" ;;
        *) echo "  FAIL $f -> $target"; exit 1 ;;
      esac
    done
    target=$(readlink "$HOME/.config/mise/config.toml" || echo NOT-A-LINK)
    case "$target" in
      *"/local-dev-setup/mise.toml") echo "  ok   mise config -> $target" ;;
      *) echo "  FAIL mise config -> $target"; exit 1 ;;
    esac

    echo
    echo "───── asserting the managed .zshrc actually loads ─────"
    # A broken .zshrc is the worst failure mode: an unusable shell on a
    # freshly wiped laptop.
    zsh -n "$HOME/.zshrc" || { echo "  FAIL .zshrc has a syntax error"; exit 1; }
    echo "  ok   .zshrc parses"
    zsh -i -c "exit" && echo "  ok   interactive zsh starts cleanly"

    echo
    echo "───── asserting mise tools resolve ─────"
    mise exec -- go version
    mise exec -- python --version

    echo
    echo "───── asserting secrets.env is 0600 ─────"
    mode=$(stat -c "%a" "$HOME/.config/devsetup/secrets.env")
    [ "$mode" = "600" ] || { echo "  FAIL secrets.env is $mode"; exit 1; }
    echo "  ok   secrets.env is 0600"

    echo
    echo "───── check mode must not error on a configured machine ─────"
    "$AP" main.yml --check --diff $EXTRA >/dev/null
    echo "  ok   --check clean"
  '

echo
ok "container test passed"
