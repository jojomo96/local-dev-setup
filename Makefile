include ./scripts/colors.mk

.PHONY: setup install uninstall clean verify update

SCRIPTS_DIR := ./scripts

# Default target
setup: install

install:
	@echo "$(WHITE)Starting setup...$(RESET)"
	@chmod +x $(SCRIPTS_DIR)/setup-mise.sh
	@$(SCRIPTS_DIR)/setup-mise.sh

# Updates everything: mise binary, standard tools, and uv-managed tools
update:
	@echo "$(WHITE)Updating environment...$(RESET)"
	@mise run update-all
	@echo "$(GREEN)Update complete!$(RESET)"

uninstall:
	@echo "$(YELLOW)Uninstalling mise and cleaning configs...$(RESET)"
	@chmod +x $(SCRIPTS_DIR)/uninstall-mise.sh
	@$(SCRIPTS_DIR)/uninstall-mise.sh

clean: uninstall

verify:
	@chmod +x $(SCRIPTS_DIR)/verify-mise.sh
	@$(SCRIPTS_DIR)/verify-mise.sh