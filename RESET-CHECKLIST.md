# Laptop reset checklist

The scripts in this repo handle software and config. This file covers everything
they **can't** — the things that are gone for good once the disk is erased.

Work top to bottom. The first section is time-critical.

---

## 🔴 BEFORE you wipe — irreversible if skipped

### Secrets and keys
- [ ] **Rotate the credentials that were in `zshrc_backup_manual`** — `VAULT_CORE_*`
      and the Stackit `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`. They sat in
      plaintext in a stray file; treat them as compromised.
- [ ] **Export your GPG secret key** — without it, every past signed commit shows
      as unverified and you can't sign new ones with the same identity:
      ```sh
      gpg --list-secret-keys --keyid-format=long
      gpg --export-secret-keys --armor <KEYID> > ~/gpg-private.asc   # store in 1Password
      gpg --export-ownertrust > ~/gpg-ownertrust.txt
      ```
- [ ] **Back up `~/.ssh/`** (or accept re-registering a new key everywhere).
      Note which hosts/services have the old public key.
- [ ] **2FA / authenticator seeds.** If your TOTP codes live only in a desktop
      app, you will lock yourself out. Move them to a phone or 1Password, and
      **download fresh recovery codes** for GitHub, cloud consoles, and email.
- [ ] **Password manager database.** With KeePass the vault is a *file*
      (`.kdbx`) — if it lives only on this disk, erasing it destroys every
      credential you own. Copy it somewhere you can reach from a bare machine
      (phone, cloud drive, USB) and verify you can actually open it there.
      Also confirm you know the master password from memory, and copy the key
      file too if your database uses one.

### Work that exists only on this disk
- [ ] Run `make capture` and read `captured/dirty-repos.txt` — commit and push
      every repo it lists.
- [ ] Repos with **no remote at all** (also flagged there) — push them somewhere
      or archive them.
- [ ] Local git **stashes** (`git stash list`) — they don't travel with a push.
- [ ] Unmerged local branches you care about.
- [ ] `.env` files, local `terraform.tfstate`, dev databases, Docker volumes
      (`docker volume ls`), local Kafka/Postgres data.
- [ ] Anything in `~/Downloads`, `~/Desktop`, `~/Documents` not in cloud storage.
- [ ] Virtual machines, Vulkan SDK projects, Xcode simulators if you need the state.

### Things you'll have to re-enter from memory otherwise
- [ ] Run `make capture` and skim `captured/config-inventory.txt`.
- [ ] **Kubeconfigs** (`~/.kube/`) — note which clusters, and how each was
      obtained (`stackit ske kubeconfig create ...`, OIDC, etc.).
- [ ] **Cloud credentials**: `~/.aws/`, `~/.config/stackit/`, VPN profiles and
      certificates.
- [ ] **App licences / activation keys** — JetBrains, Dash, TablePlus, anything
      bought outside the App Store. Screenshot the licence screens.
- [ ] **Browser**: make sure bookmarks, passwords and profiles are synced, and
      note the extensions you rely on.
- [ ] **IDE settings**: enable JetBrains Settings Sync and VS Code Settings Sync
      *now*, while the old setup still exists.
- [ ] `/etc/hosts` entries you added by hand.
- [ ] `~/Library/LaunchAgents/` — custom background jobs, plus `crontab -l`.
- [ ] Shell history, if you grep it for old commands (`~/.zsh_history`).
- [ ] Signal / WhatsApp desktop — linked-device state is lost; note re-linking.
- [ ] **Time Machine or equivalent full backup.** Do this even if you think the
      checklist is complete; it is the only real undo.

### Final step
- [ ] `git add -A && git commit && git push` in this repo, and verify on GitHub
      that `Brewfile`, `dotfiles/` and `mise.toml` are all there.
- [ ] Confirm `secrets.env` and `captured/` are **not** in the pushed tree.
- [ ] Sign out of iCloud, Find My, and the App Store; deauthorise licensed apps.

---

## 🟡 AFTER the reset — in this order

1. [ ] macOS Setup Assistant, sign in to Apple ID, run Software Update to completion.
2. [ ] **Enable FileVault** (System Settings → Privacy & Security) before putting
       any credentials back on the machine.
3. [ ] Install a browser, then KeePassXC, then **restore your `.kdbx` file** and
       confirm it opens. Everything below needs credentials out of it, so do not
       continue until this works.
4. [ ] Bootstrap this repo:
       ```sh
       /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jojomo96/local-dev-setup/main/bootstrap.sh)"
       ```
5. [ ] `gh auth login`, then `gh ssh-key add ~/.ssh/id_ed25519.pub`.
6. [ ] Import GPG key: `gpg --import ~/gpg-private.asc && gpg --import-ownertrust ~/gpg-ownertrust.txt`,
       then `make identity` to wire up signing.
7. [ ] Restore `~/.kube/`, `~/.aws/`, `~/.config/stackit/` — or re-create them
       with `stackit auth login` and fresh, short-lived credentials.
8. [ ] Fill in `~/.config/devsetup/secrets.env` with the **rotated** values.
9. [ ] `make doctor` — resolve every failure before you start working.
10. [ ] Sign in to Slack, Docker Hub, JetBrains; re-enable IDE settings sync.
11. [ ] Re-add VS Code extensions: `cat captured/vscode-extensions.txt | xargs -n1 code --install-extension`
12. [ ] Re-install krew plugins from `captured/krew-plugins.txt`.
13. [ ] Set up Time Machine on the new install.

---

## 🟢 Keep it from rotting

- Anything you install by hand, add to `Brewfile` or `mise.toml` **the same day**.
- Run `make check` occasionally — a dry run showing exactly what has drifted.
- Run `make doctor` for the things Ansible can't see: brew shadowing a mise
  tool on PATH, duplicate declarations, secret leaks.
- Run `make test` after editing the playbook — a broken `.zshrc` on a fresh
  laptop means no working shell. CI asserts a second run reports `changed=0`.
- Re-read this checklist before the *next* reset and fix what was wrong.
