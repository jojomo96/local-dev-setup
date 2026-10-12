include ./scripts/colors.mk

PLAYBOOK := main.yml
SCRIPTS  := ./scripts

# Resolve Ansible: prefer whatever is on PATH (uv installs ansible-core into
# ~/.local/bin via uv-tools.list), and fall back to the throwaway venv that
# bootstrap.sh creates before uv exists.
BOOTSTRAP_VENV := $(HOME)/.local/share/devsetup/bootstrap-venv
ANSIBLE_PLAYBOOK := $(shell command -v ansible-playbook 2>/dev/null \
	|| echo $(BOOTSTRAP_VENV)/bin/ansible-playbook)
ANSIBLE_GALAXY := $(shell command -v ansible-galaxy 2>/dev/null \
	|| echo $(BOOTSTRAP_VENV)/bin/ansible-galaxy)
ANSIBLE_VAULT := $(shell command -v ansible-vault 2>/dev/null \
	|| echo $(BOOTSTRAP_VENV)/bin/ansible-vault)

.PHONY: help bootstrap deps pin-deps check brew dotfiles mise k9s plugins \
        identity macos doctor update capture lint test vault clean clean-venv

help:
	@echo ""
	@echo "$(BOLD)local-dev-setup$(RESET) — Ansible-managed macOS dev laptop"
	@echo ""
	@echo "  $(BOLD)Before wiping the old laptop$(RESET)"
	@echo "    make capture      Snapshot installed software, find unpushed work"
	@echo ""
	@echo "  $(BOLD)On the new laptop$(RESET)"
	@echo "    ./bootstrap.sh    Installs Ansible, then runs the playbook"
	@echo "    make bootstrap    Same, if the repo is already cloned"
	@echo ""
	@echo "  $(BOLD)Everyday$(RESET)"
	@echo "    make check        Dry run: show what would change (no writes)"
	@echo "    make doctor       check + hygiene checks Ansible can't do"
	@echo "    make update       Update mise tools, uv tools and brew"
	@echo ""
	@echo "  $(BOLD)Single areas$(RESET) (playbook tags)"
	@echo "    make brew dotfiles mise k9s plugins identity macos"
	@echo ""
	@echo "  $(BOLD)Maintenance$(RESET)"
	@echo "    make deps         Install Ansible collections"
	@echo "    make pin-deps     Show resolved versions to pin in requirements.yml"
	@echo "    make lint         yamllint + ansible-lint + syntax check"
	@echo "    make test         Run the playbook twice in a Linux container"
	@echo "    make vault        Edit the encrypted secrets file"
	@echo ""

# ── Setup ───────────────────────────────────────────────────────────────────
bootstrap:
	@chmod +x ./bootstrap.sh $(SCRIPTS)/*.sh
	@./bootstrap.sh

deps:
	@$(ANSIBLE_GALAXY) install -r requirements.yml

pin-deps:
	@echo "$(WHITE)Installed collection versions — copy these into requirements.yml:$(RESET)"
	@$(ANSIBLE_GALAXY) collection list 2>/dev/null | grep -E '^(community|ansible)\.' || true

# ── Dry run and verification ────────────────────────────────────────────────
check:
	@$(ANSIBLE_PLAYBOOK) $(PLAYBOOK) --check --diff

doctor: check
	@chmod +x $(SCRIPTS)/*.sh
	@$(SCRIPTS)/doctor.sh

# ── Single areas ────────────────────────────────────────────────────────────
brew:
	@$(ANSIBLE_PLAYBOOK) $(PLAYBOOK) --tags brew

dotfiles:
	@$(ANSIBLE_PLAYBOOK) $(PLAYBOOK) --tags dotfiles

mise:
	@$(ANSIBLE_PLAYBOOK) $(PLAYBOOK) --tags mise

identity:
	@$(ANSIBLE_PLAYBOOK) $(PLAYBOOK) --tags identity

k9s:
	@$(ANSIBLE_PLAYBOOK) $(PLAYBOOK) --tags k9s

plugins:
	@$(ANSIBLE_PLAYBOOK) $(PLAYBOOK) --tags plugins

macos:
	@$(ANSIBLE_PLAYBOOK) $(PLAYBOOK) --tags macos

# ── Maintenance ─────────────────────────────────────────────────────────────
update:
	@echo "$(WHITE)Updating mise, its tools, and uv tools...$(RESET)"
	@$(HOME)/.local/bin/mise run update-all
	@command -v brew >/dev/null && { \
		echo "$(WHITE)Updating Homebrew...$(RESET)"; \
		brew update && brew upgrade && brew cleanup; \
	} || true
	@echo "$(GREEN)Update complete.$(RESET)"

capture:
	@chmod +x $(SCRIPTS)/*.sh
	@$(SCRIPTS)/capture.sh

lint:
	@$(ANSIBLE_PLAYBOOK) $(PLAYBOOK) --syntax-check
	@command -v yamllint >/dev/null \
		&& yamllint . \
		|| echo "$(YELLOW)yamllint not installed, skipped$(RESET)"
	@command -v ansible-lint >/dev/null \
		&& ansible-lint \
		|| echo "$(YELLOW)ansible-lint not installed, skipped$(RESET)"
	@$(SCRIPTS)/check-duplicates.sh
	@for f in $(SCRIPTS)/*.sh ./bootstrap.sh; do bash -n "$$f" || exit 1; done
	@echo "$(GREEN)lint clean$(RESET)"

test:
	@chmod +x $(SCRIPTS)/*.sh
	@$(SCRIPTS)/test-in-docker.sh

vault:
	@$(ANSIBLE_VAULT) edit group_vars/vault.yml

clean:
	@rm -rf collections/ captured/ Brewfile.audit
	@echo "$(GREEN)Removed generated files.$(RESET)"

# The bootstrap venv exists only to run the playbook before uv is available.
# Once uv-tools.list has installed ansible-core into ~/.local/bin, it's dead
# weight. Refuses to delete it if that permanent copy isn't there yet.
clean-venv:
	@if [ -x "$(HOME)/.local/bin/ansible-playbook" ]; then \
		rm -rf "$(BOOTSTRAP_VENV)"; \
		echo "$(GREEN)Removed bootstrap venv; using $(HOME)/.local/bin/ansible-playbook.$(RESET)"; \
	else \
		echo "$(YELLOW)Keeping the bootstrap venv: no uv-installed ansible-playbook"; \
		echo "found in ~/.local/bin. Run 'make mise' first.$(RESET)"; \
	fi
