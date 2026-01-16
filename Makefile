# Makefile

# Define colors
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

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
	@echo "$(WHITE)Verifying mise installation...$(RESET)"
	@chmod +x $(SCRIPTS_DIR)/verify-mise.sh
	@$(SCRIPTS_DIR)/verify-mise.sh
