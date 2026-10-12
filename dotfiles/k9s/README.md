# k9s config

Managed by `tasks/k9s.yml` (`make k9s`). On macOS k9s reads from
`~/Library/Application Support/k9s` — note the space, and note that it is *not*
`~/.config/k9s`.

## Layout

```
skins/                          symlinked into place; the repo owns these
clusters/<cluster>/<context>/
  config.yaml                   copied once if absent, then k9s owns it
```

## Why two different strategies

**Skins are symlinked.** They're pure colour definitions and nothing but you
ever edits them, so the repo can own them outright.

**Context configs are copied, not symlinked.** That file holds two things you
want to keep — the `skin:` mapping and your curated `favorites` namespace list —
but k9s *also* rewrites `namespace.active` and `view.active` into it every time
you use it. Symlinking would leave the git tree dirty after every session, so
the playbook seeds the file with `force: false` and then leaves it alone
forever.

The root `config.yaml` is deliberately unmanaged: it contains only k9s defaults
plus an absolute `screenDumpDir` path that wouldn't survive moving machines.

## Populating this from a live machine

```sh
K9S="$HOME/Library/Application Support/k9s"

# Skins
mv "$K9S/skins/"*.y*ml dotfiles/k9s/skins/

# Context configs (adjust to your clusters; see k9s_cluster_configs in
# group_vars/all.yml)
mkdir -p dotfiles/k9s/clusters/dns/dns
cp "$K9S/clusters/dns/dns/config.yaml" dotfiles/k9s/clusters/dns/dns/

mkdir -p dotfiles/k9s/clusters/dns-nonprod/dns-nonprod
cp "$K9S/clusters/dns-nonprod/dns-nonprod/config.yaml" \
   dotfiles/k9s/clusters/dns-nonprod/dns-nonprod/

make k9s
```

`make k9s` also reports any skin present on the machine but missing from the
repo, so nothing gets silently left behind.

## How the per-cluster colours actually work

The `skin:` key in a context's `config.yaml` names a file in `skins/`:

```yaml
k9s:
  cluster: dns
  skin: red        # -> skins/red.yaml
```

A context with no `skin:` key gets the default colours. Red for production is
worth keeping — it's the context where running the wrong command costs most.
