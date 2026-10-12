# local-dev-setup

Ansible-managed macOS development laptop: Homebrew apps, mise-managed runtimes,
repo-owned dotfiles, macOS system preferences.

One command on a freshly reset machine:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jojomo96/local-dev-setup/main/bootstrap.sh)"
```

`curl` fetches just this one script's text; `bash` runs it from memory and it
clones the repo itself into `~/local-dev-setup`. Nothing needs to exist first.

Equivalent, if you'd rather see what you're running before you run it:

```sh
git clone https://github.com/jojomo96/local-dev-setup.git
cd local-dev-setup
./bootstrap.sh
```

---

## Doing a laptop reset

**On the old machine, before wiping:**

```sh
make capture     # snapshots installed software, finds unpushed work
```

Open `Brewfile.audit`, uncomment only what you actually want to keep, and move
those lines into `Brewfile`. Everything you leave commented simply never gets
installed again — that's how the garbage stays behind.

Then work through **[RESET-CHECKLIST.md](RESET-CHECKLIST.md)** — 2FA seeds, your
KeePass `.kdbx` file, licences, kubeconfigs. The things no script can restore.
It tells you how to check whether each one applies to you rather than assuming.

**On the new machine:** either command at the top. Neither needs credentials
while the repo is public.

> **If you make this repo private, the one-liner breaks** — its HTTPS clone
> would need credentials that don't exist yet on a bare machine. Use the
> clone-first path after `gh auth login`, or clone over SSH.

Afterwards, the things the playbook can't do for you:

```sh
# restore ~/.kube/ — nothing can recreate your cluster credentials
make doctor
gh auth login     # only needed the first time you push a change back
```

---

## Commands

| Command | What it does |
|---|---|
| `make capture` | Snapshot the old laptop → `captured/`, `Brewfile.audit` |
| `./bootstrap.sh` | Install Ansible, then run the playbook |
| `make check` | **Dry run** — shows exactly what would change, writes nothing |
| `make doctor` | `check` plus the hygiene checks Ansible can't do |
| `make brew` | Sync Homebrew to `Brewfile` (**removes** anything not listed) |
| `make dotfiles` / `mise` / `identity` / `macos` | Single areas (playbook tags) |
| `make update` | Update mise tools, uv tools, brew |
| `make lint` | yamllint + ansible-lint + syntax + shellcheck |
| `make test` | Run the playbook twice in a container, assert `changed=0` |
| `make pin-deps` | Show resolved collection versions to pin |

---

## Layout

```
bootstrap.sh          the ONLY imperative code: CLT check, venv + Ansible, hand over
main.yml              the playbook
group_vars/all.yml    single place to configure this machine
requirements.yml      Ansible collections
tasks/
  homebrew.yml        brew install + `brew bundle --cleanup`
  omz.yml             oh-my-zsh + custom plugins
  dotfiles.yml        symlinks, with timestamped backups
  mise.yml            runtimes + uv tools
  identity.yml        git identity, SSH key, GPG signing, gh
  macos.yml           community.general.osx_defaults

Brewfile              GUI apps, fonts, zsh plugins, system CLIs
mise.toml             language runtimes + versioned CLIs
uv-tools.list         Python CLI tools
dotfiles/zsh/.zshrc   your shell config — ~/.zshrc is a symlink to it
scripts/
  capture.sh          pre-reset snapshot (no Ansible equivalent exists)
  doctor.sh           PATH resolution + secret hygiene
  check-duplicates.sh enforces one-tool-one-manager
  test-in-docker.sh   container test
```

### The two rules

1. **A tool belongs to exactly one manager.** In `mise.toml` means not in the
   `Brewfile`. Two copies is a PATH-order coin flip over which version you get.
   `check-duplicates.sh` enforces it in CI; `doctor.sh` catches the runtime case
   where brew is actually shadowing a mise tool.
2. **The repo owns dotfiles; `$HOME` holds symlinks.** Never hand-edit
   `~/.zshrc` — it points at `dotfiles/zsh/.zshrc`. Edit there and commit.

### How Ansible itself gets installed

Chicken-and-egg: Ansible configures the machine, but nothing is installed yet.

1. `bootstrap.sh` creates a venv at `~/.local/share/devsetup/bootstrap-venv`
   from the system `python3` (provided by the Xcode CLT) and installs
   `ansible-core` into it. `venv` is in the standard library, so there's nothing
   to install first — unlike pipx, which would itself need `pip install --user`.
   The binary is then called by absolute path, so there's no guessing at
   `~/Library/Python/<version>/bin`, whose version varies by macOS release.
2. The playbook installs mise → uv → `ansible-core` (declared in
   `uv-tools.list`) into `~/.local/bin`, which is the permanent copy.
3. `make clean-venv` deletes the bootstrap venv once that permanent copy exists.

The Makefile prefers whatever `ansible-playbook` is on `PATH` and falls back to
the bootstrap venv, so both stages work without you thinking about it.

### Why Brewfile instead of Ansible variables

`geerlingguy.mac.homebrew` is the usual recommendation and its install logic is
good, but it can only express "install these packages" — not "uninstall
everything not on this list". That allowlist behaviour is the whole point here,
and `brew bundle --cleanup` is the only thing that provides it. So the Brewfile
stays the source of truth and Ansible drives it.

### Where things that aren't in git live

| What | Where | Why not in the repo |
|---|---|---|
| Credentials | `~/.config/devsetup/secrets.env` (0600) | secrets |
| git name/email | `~/.config/git/identity` | personal data |
| Machine-specific shell tweaks | `~/.zshrc.local` | differs per machine |

For secrets, prefer not storing them at all: `stackit auth login` for
short-lived tokens, or `direnv` scoped to the one project that needs keys.
`ansible-vault` is wired up (`make vault`) if you want encrypted values in the
repo — keep the vault password in KeePass.

---

## Testing

`make test` builds a container and runs the playbook **twice**. The headline
assertion is Ansible's own recap reporting `changed=0` on the second run — a
machine-checked idempotency guarantee across every task. It then asserts the
symlinks resolve into the repo, that `~/.zshrc` both parses *and* starts an
interactive zsh cleanly, that the runtimes install, that `secrets.env` is 0600,
and that `--check` is clean afterwards.

Linux can't test Homebrew or `osx_defaults`, so CI runs the same playbook on a
`macos-latest` runner with the same idempotency assertion, plus yamllint,
ansible-lint, shellcheck and gitleaks.

---

## History

This started as ~600 lines of bash that patched a managed block into a live
`~/.zshrc` with `sed`. Two rewrites later:

**What the bash version got wrong**
- Hand-rolled plumbing carried the bugs: a `${var/#$HOME/~}` substitution that
  silently never fired, a `stat -f` flag that means something different on GNU,
  an over-broad glob. All three live in code that `ansible.builtin.file` and
  friends simply don't have.
- `cp file file.bak` on every run meant the second run overwrote the good backup
  with the already-modified file.
- The `[tools]` list was duplicated into a shell function and had already
  drifted (`go = "1.25.5"` vs `go = "latest"`). It's now one symlinked file.
- 30 unconditional `defaults write` calls that couldn't report what changed.
  `osx_defaults` reads first and tells you.
- Four live credentials sat in the tracked-adjacent `zshrc_backup_manual`.

**Why Ansible and not chezmoi or Nix**
Nix is strongest on reproducibility — `flake.lock` pins the exact package set,
switches are atomic, rollback is real. But its purity stops at Homebrew casks,
which is half of a dev laptop, and a config you can't debug on a freshly wiped
machine is worse than one you can read. Ansible was already familiar, and
`osx_defaults` / `file` / `git_config` replace precisely the code that was
hand-rolled worst.

The cheap version of Nix's main benefit is still available: pin real versions in
`mise.toml` instead of `"latest"`, so `make update` becomes a reviewable diff.
