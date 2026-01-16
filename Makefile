include ./scripts/colors.mk

.PHONY: setup install uninstall clean verify

SCRIPTS_DIR := ./scripts

# Default target
setup: install

install:
	@echo "$(WHITE)Starting setup...$(RESET)"
	@chmod +x $(SCRIPTS_DIR)/setup-mise.sh
	@$(SCRIPTS_DIR)/setup-mise.sh

uninstall:
	@echo "$(YELLOW)Uninstalling mise and cleaning configs...$(RESET)"
	@chmod +x $(SCRIPTS_DIR)/uninstall-mise.sh
	@$(SCRIPTS_DIR)/uninstall-mise.sh

# 'clean' is a common alias for uninstall/cleanup
clean: uninstall

verify:
	@chmod +x $(SCRIPTS_DIR)/verify-mise.sh
	@$(SCRIPTS_DIR)/verify-mise.sh
