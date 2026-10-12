# Laptop reset checklist

The scripts in this repo handle software and config. This file covers everything
they **can't** — the things that are gone for good once the disk is erased.

Work top to bottom. The first section is time-critical.

**Start here:** run `make capture` and open `captured/config-inventory.txt`. It
lists which of the files below actually exist on this machine, so you only work
through the ones that apply to you instead of guessing.

---

## 🔴 BEFORE you wipe — irreversible if skipped

### Secrets and keys
- [ ] **Rotate the credentials that were in `zshrc_backup_manual`** — `VAULT_CORE_*`
      and the Stackit `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`. They sat in
      plaintext in a stray file; treat them as compromised.
- [ ] **Back up `~/.ssh/`** (or accept re-registering a new key everywhere).
      Note which hosts/services have the old public key. A fresh laptop gets a
      new key, and GitHub won't recognise it until you upload it — see the
      `gh ssh-key add` step in the after-reset section.
- [ ] **GPG secret key — only if you have one.** Check: `gpg --list-secret-keys`
      If that prints nothing, you've never signed commits. Skip this entirely;
      nothing will break. If it *does* print a key, export it, because without
      it every past signed commit shows as unverified:
      ```sh
      gpg --list-secret-keys --keyid-format=long
      gpg --export-secret-keys --armor <KEYID> > ~/gpg-private.asc   # store in KeePass
      gpg --export-ownertrust > ~/gpg-ownertrust.txt
      ```
- [ ] **2FA / authenticator seeds.** If your TOTP codes live only in a desktop
      app, you will lock yourself out. Move them to your phone or KeePass, and
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
- [ ] Skim `captured/config-inventory.txt` — it marks each path EXISTS or `-`,
      so you can ignore anything you don't actually have.
- [ ] **Kubeconfigs** (`~/.kube/`) — ⚠️ **you have these and nothing can
      recreate them.** The old setup referenced `core-game.yml` and
      `dns-nonprd-oidc.json`. Copy the whole directory, and write down how each
      cluster was obtained (`stackit ske kubeconfig create ...`, OIDC login,
      handed over by a colleague). Without them `kubectl` and `k9s` reach
      nothing.
- [ ] **Cloud credentials**: `~/.config/stackit/`, VPN profiles, certificates.
      Also `~/.aws/` — but check whether it exists (`ls ~/.aws`): the old setup
      used `AWS_ACCESS_KEY_ID` environment variables rather than a credentials
      file, so there may be nothing there to copy. In that case the rotated
      values just go into `~/.config/devsetup/secrets.env`.
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
4. [ ] Bootstrap this repo. Needs no credentials while the repo is public; it
       clones itself into `~/local-dev-setup`:
       ```sh
       /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jojomo96/local-dev-setup/main/bootstrap.sh)"
       ```
       Save that line as a note in KeePass — on a bare laptop you'll otherwise
       be retyping it from the GitHub web UI. Or clone manually:
       `git clone https://github.com/jojomo96/local-dev-setup.git && cd local-dev-setup && ./bootstrap.sh`
5. [ ] **GitHub auth** — not needed to clone or bootstrap (this repo is public
       and `bootstrap.sh` clones over HTTPS). You need it the first time you
       want to *push* a change back, e.g. after adding a package to the
       Brewfile. `gh auth login` configures git's credential helper, which is
       enough on its own:
       ```sh
       gh auth login
       ```
       Optional, only if you prefer SSH remotes over HTTPS:
       ```sh
       gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname -s)"
       ```
6. [ ] GPG — **skip unless you exported a key earlier.** If you did:
       `gpg --import ~/gpg-private.asc && gpg --import-ownertrust ~/gpg-ownertrust.txt`,
       then `make identity` to wire up signing.
7. [ ] Restore `~/.kube/` (required for any cluster work) and
       `~/.config/stackit/`. Prefer re-creating them with `stackit auth login`
       and fresh short-lived credentials over copying long-lived keys across.
       Verify with `kubectl config get-contexts`.
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
