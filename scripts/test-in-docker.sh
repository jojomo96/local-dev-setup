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
      python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

# PEP 668 marks the system Python as externally managed; this is a throwaway
# container, so installing into it is fine.
RUN pip3 install --break-system-packages --quiet ansible-core

RUN useradd -m -s /bin/zsh tester
USER tester
WORKDIR /home/tester/local-dev-setup
COPY --chown=tester:tester . .
DOCKERFILE

step "Running the playbook twice"
info "Homebrew and macOS tasks are skipped (Linux)."
echo

docker run --rm -i "$IMAGE" bash -lc '
    set -euo pipefail
    export PATH="$HOME/.local/bin:$PATH"
    export ANSIBLE_FORCE_COLOR=1

    ansible-galaxy install -r requirements.yml

    EXTRA="-e configure_homebrew=false -e configure_macos=false \
           -e git_user_name=Test -e git_user_email=test@example.com"

    echo "───── syntax check ─────"
    ansible-playbook main.yml --syntax-check

    echo
    echo "───── run 1: apply ─────"
    ansible-playbook main.yml $EXTRA

    echo
    echo "───── run 2: must report changed=0 ─────"
    ansible-playbook main.yml $EXTRA | tee /tmp/run2.log

    echo
    echo "───── asserting idempotency ─────"
    recap=$(grep -E "^localhost *:" /tmp/run2.log || true)
    echo "  recap: $recap"
    if ! echo "$recap" | grep -q "changed=0"; then
      echo "  FAIL second run was not idempotent"
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
    ansible-playbook main.yml --check --diff $EXTRA >/dev/null
    echo "  ok   --check clean"
  '

echo
ok "container test passed"
