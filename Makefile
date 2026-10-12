include ./scripts/colors.mk

PLAYBOOK := main.yml
SCRIPTS  := ./scripts

.PHONY: help bootstrap deps pin-deps check brew dotfiles mise identity macos \
        doctor update capture lint test vault clean

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
	@echo "    make brew dotfiles mise identity macos"
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
	@ansible-galaxy install -r requirements.yml

pin-deps:
	@echo "$(WHITE)Installed collection versions — copy these into requirements.yml:$(RESET)"
	@ansible-galaxy collection list 2>/dev/null | grep -E '^(community|ansible)\.' || true

# ── Dry run and verification ────────────────────────────────────────────────
check:
	@ansible-playbook $(PLAYBOOK) --check --diff

doctor: check
	@chmod +x $(SCRIPTS)/*.sh
	@$(SCRIPTS)/doctor.sh

# ── Single areas ────────────────────────────────────────────────────────────
brew:
	@ansible-playbook $(PLAYBOOK) --tags brew

dotfiles:
	@ansible-playbook $(PLAYBOOK) --tags dotfiles

mise:
	@ansible-playbook $(PLAYBOOK) --tags mise

identity:
	@ansible-playbook $(PLAYBOOK) --tags identity

macos:
	@ansible-playbook $(PLAYBOOK) --tags macos

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
	@ansible-playbook $(PLAYBOOK) --syntax-check
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
	@ansible-vault edit group_vars/vault.yml

clean:
	@rm -rf collections/ captured/ Brewfile.audit
	@echo "$(GREEN)Removed generated files.$(RESET)"
