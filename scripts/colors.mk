# Shared Makefile color definitions
# Included from the repository Makefile.
# Guarded: expand to empty strings when tput is unavailable (e.g. CI).

RED    := $(shell tput -Txterm setaf 1 2>/dev/null)
GREEN  := $(shell tput -Txterm setaf 2 2>/dev/null)
YELLOW := $(shell tput -Txterm setaf 3 2>/dev/null)
BLUE   := $(shell tput -Txterm setaf 4 2>/dev/null)
WHITE  := $(shell tput -Txterm setaf 7 2>/dev/null)
BOLD   := $(shell tput -Txterm bold 2>/dev/null)
RESET  := $(shell tput -Txterm sgr0 2>/dev/null)
