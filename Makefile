# Makefile

.PHONY: setup install uninstall clean

# Default target
setup: install

install:
	@echo "🚀 Starting setup..."
	@chmod +x setup.sh
	@./scripts/setup.sh

uninstall:
	@echo "🗑️  Uninstalling mise and cleaning configs..."
	@chmod +x uninstall.sh
	@./scripts/uninstall.sh

# 'clean' is a common alias for uninstall/cleanup
clean: uninstall