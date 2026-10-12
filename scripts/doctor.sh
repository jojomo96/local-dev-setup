#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# doctor.sh — the checks Ansible can't do for you.
#
# `ansible-playbook main.yml --check --diff` already covers config drift: it
# will tell you about a missing symlink or a changed macOS default far better
# than a shell script can. `make doctor` runs that first, then this.
#
# What's left here is the stuff that isn't desired-state at all:
#   - which binary actually wins on PATH (brew shadowing a mise tool)
#   - external auth state (gh)
#   - credential hygiene in the repo and working tree
#
# Read-only. Exit 1 if anything required fails.
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail   # no -e: every check should run

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

FAILURES=0
WARNINGS=0

echo
echo "${BOLD}  hygiene checks${RESET}"
echo

# ── PATH resolution: the failure Ansible cannot see ─────────────────────────
# A tool declared in mise but also installed by brew leaves two binaries on
# PATH, and which one you get depends on PATH order. Declaration checks pass;
# the wrong version still runs.
step "Tool resolution (mise-declared tools must resolve to mise)"
for t in go python node kubectl helm terraform tflint k9s jq yq aws; do
  if ! have "$t"; then
    warn "$(printf '%-12s' "$t") not found"
    (( WARNINGS++ ))
    continue
  fi
  path="$(command -v "$t")"
  if [[ "$path" == *mise* ]]; then
    ok "$(printf '%-12s' "$t") $path"
  else
    fail "$(printf '%-12s' "$t") resolves to $path, not mise — brew is shadowing it"
    (( FAILURES++ ))
  fi
done

# ── Declaration hygiene ────────────────────────────────────────────────────
echo
"$REPO_ROOT/scripts/check-duplicates.sh" || (( FAILURES++ ))

# ── External auth ──────────────────────────────────────────────────────────
echo
step "Authentication"
if have gh; then
  gh auth status >/dev/null 2>&1 \
    && ok "gh authenticated" \
    || { warn "gh not authenticated — run: gh auth login"; (( WARNINGS++ )); }
else
  warn "gh not installed"; (( WARNINGS++ ))
fi

# Report whatever keys exist rather than expecting one specific filename:
# a Secure Enclave key lives in Secretive's agent and has no file at all.
ssh_keys=$(find "$HOME/.ssh" -maxdepth 1 -name '*.pub' 2>/dev/null | wc -l | tr -d ' ')
if [[ "${ssh_keys:-0}" -gt 0 ]]; then
  ok "$ssh_keys SSH public key(s) in ~/.ssh"
else
  warn "no SSH key files in ~/.ssh (fine if you only use Secretive's agent)"
  (( WARNINGS++ ))
fi
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
  key_count=$(ssh-add -l 2>/dev/null | grep -c . || true)
  [[ "${key_count:-0}" -gt 0 ]] \
    && ok "ssh-agent has ${key_count} key(s) loaded" \
    || warn "ssh-agent is running but holds no keys"
fi
# Not signing commits is a perfectly valid choice, so this is informational
# rather than a warning — it would otherwise nag forever.
if [[ "$(git config commit.gpgsign 2>/dev/null)" == "true" ]]; then
  ok "commit signing enabled (format: $(git config gpg.format 2>/dev/null || echo openpgp))"
else
  info "commit signing off (set git_signing_ssh_key to enable)"
fi

# ── Secrets hygiene ────────────────────────────────────────────────────────
echo
step "Secrets hygiene"
SECRETS="$HOME/.config/devsetup/secrets.env"
if [[ -f "$SECRETS" ]]; then
  perms="$(file_mode "$SECRETS")"
  [[ "$perms" == "600" ]] \
    && ok "secrets.env permissions are 600" \
    || { fail "secrets.env is mode ${perms:-unknown}, should be 600"; (( FAILURES++ )); }
fi

# Credential-shaped values in tracked files. gitleaks does this far better;
# this is the zero-dependency backstop for when it isn't installed.
if have gitleaks; then
  if gitleaks detect --source "$REPO_ROOT" --no-banner --redact -v >/dev/null 2>&1; then
    ok "gitleaks found no secrets"
  else
    fail "gitleaks found secrets — run: gitleaks detect --source . -v"
    (( FAILURES++ ))
  fi
else
  warn "gitleaks not installed (brew install gitleaks) — using a weak fallback"
  (( WARNINGS++ ))
  if git -C "$REPO_ROOT" grep -lI -E \
       '(AWS_SECRET_ACCESS_KEY|VAULT_CORE_PASSWORD|AWS_ACCESS_KEY_ID)[[:space:]]*=[[:space:]]*"?[A-Za-z0-9/+_,?.-]{12,}' \
       -- . ':(exclude)secrets.env.example' >/dev/null 2>&1; then
    fail "possible credential in a tracked file"
    (( FAILURES++ ))
  else
    ok "no credentials detected in tracked files"
  fi
fi

# Stray rc-file backups. Scanned from the filesystem, not `git status`,
# because .gitignore hides exactly the files that matter — an ignored
# zshrc_backup_manual is still a plaintext credential file on disk.
strays=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$(basename "$f")" in
    *backup*|*.bak|*.bak.*|*.save|*.orig|zshrc*|bashrc*)
      strays+="  $(pretty_path "$f")"$'\n' ;;
  esac
done < <(find "$REPO_ROOT" -maxdepth 2 -type f -not -path '*/.git/*' 2>/dev/null)
if [[ -n "$strays" ]]; then
  fail "stray rc-file backups in the repo — these have held live credentials:"
  printf '%s' "$strays" | sed 's/^/      /'
  info "      Review, copy anything you still need, then delete them."
  (( FAILURES++ ))
else
  ok "no stray rc-file backups in the repo"
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo
if (( FAILURES == 0 && WARNINGS == 0 )); then
  echo "  ${GREEN}${BOLD}All hygiene checks passed.${RESET}"
elif (( FAILURES == 0 )); then
  echo "  ${GREEN}No failures${RESET}, ${YELLOW}$WARNINGS warning(s)${RESET}."
else
  echo "  ${RED}${BOLD}$FAILURES failure(s)${RESET}, ${YELLOW}$WARNINGS warning(s)${RESET}."
fi
echo
(( FAILURES == 0 ))
