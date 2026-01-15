# Makefile

.PHONY: setup install uninstall clean

SCRIPTS_DIR := ./scripts

# Default target
setup: install

install:
	@echo "🚀 Starting setup..."
	@chmod +x $(SCRIPTS_DIR)/setup-mise.sh
	@$(SCRIPTS_DIR)/setup-mise.sh

uninstall:
	@echo "🗑️  Uninstalling mise and cleaning configs..."
	@chmod +x $(SCRIPTS_DIR)/uninstall-mise.sh
	@$(SCRIPTS_DIR)/uninstall-mise.sh

# 'clean' is a common alias for uninstall/cleanup
clean: uninstall