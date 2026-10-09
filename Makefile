.DEFAULT_GOAL := help

# VARIABLES

# Generated OpenCode tree. gen writes here; check verifies it matches source.
OPENCODE_OUT ?= opencode

# spproof proves .spproof.yml over the tree. The pin is the one place the
# version lives; versions.md must agree (policy checks it) and tools installs
# exactly it through the release's install.sh, which verifies checksums.
SPPROOF_VERSION ?= v0.2.0
SPPROOF_INSTALL_DIR ?= $(HOME)/.local/bin
SPPROOF ?= $(SPPROOF_INSTALL_DIR)/spproof

# Python dependencies of the checks, maintainer-side only: nothing under
# plugins/ imports them. tools installs them into a repo-local venv, because
# the system Python refuses pip installs (PEP 668). When the venv exists every
# recipe's python3 resolves into it; otherwise the system python3 runs and a
# missing tiktoken degrades to SKIP.
VENV ?= .venv
PY_DEPS ?= tiktoken==0.12.0 pyyaml==6.0.3
ifneq ($(wildcard $(VENV)/bin/python3),)
export PATH := $(CURDIR)/$(VENV)/bin:$(PATH)
endif

# Every POSIX sh script the repo runs or ships. release.sh is bash and is
# not in this set: -s sh would lint it as the wrong dialect.
SHELL_SCRIPTS = scripts/*.sh plugins/10x/hooks/*.sh \
	plugins/10x/skills/_shared/references/claim.sh \
	plugins/10x/skills/_shared/references/resolve-paths.sh

# PHONY DECLARATIONS (in alphabetical order)
.PHONY: check confirm gen help install-opencode policy shellcheck tokens tools uninstall-opencode

# STANDARD TARGETS (in alphabetical order)

## check: run every static check, in the same order as CI
check: shellcheck policy
	@sh scripts/check-skill-references.sh
	@$(MAKE) --no-print-directory tokens
	@sh scripts/check-rule-duplication.sh
	@sh scripts/check-dangling-refs.sh
	@sh scripts/check-artifact-registry.sh
	@sh scripts/check-opencode-sync.sh
	@sh scripts/check-harness-matrix.sh
	@sh scripts/check-no-personal-paths.sh
	@sh scripts/check-naming.sh
	@sh scripts/test-hooks.sh
	@sh scripts/test-install-opencode.sh
	@sh scripts/test-claim.sh
	@sh scripts/test-token-gate.sh

## gen: regenerate the OpenCode commands and agents from plugin source
gen:
	@sh scripts/gen-opencode.sh $(OPENCODE_OUT)

## help: display this help message
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

## policy: prove .spproof.yml holds over the tree; installs the pinned spproof when absent or stale
policy:
	@$(SPPROOF) --version 2>/dev/null | grep -q '^spproof $(SPPROOF_VERSION) ' || $(MAKE) tools
	@grep -q '| spproof | `$(SPPROOF_VERSION)` |' plugins/10x/skills/_shared/references/versions.md \
		|| { echo "versions.md pins a different spproof than SPPROOF_VERSION=$(SPPROOF_VERSION)"; exit 1; }
	@$(SPPROOF) check --policy .spproof.yml .
	@$(SPPROOF) check --policy .spproof.yml --format json . | python3 -c 'import json,sys; \
		idle=[r["id"] for r in json.load(sys.stdin)["rules"] if r["evaluatedFiles"]==0]; \
		sys.exit("policy: rule(s) matched no file, a moved target would pass silently: "+", ".join(idle) if idle else 0)'
	@echo 'policy: every rule held and every rule ran'

## shellcheck: lint the POSIX sh scripts (warning and above); skipped with a notice when the tool is absent
shellcheck:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -s sh -S warning $(SHELL_SCRIPTS) && echo 'shellcheck: clean'; \
	else \
		echo 'SKIP shellcheck: install shellcheck 0.11.0 to run it locally (CI always does)'; \
	fi

## tokens: enforce the skill token budget; SKIP only when tiktoken cannot be imported
tokens:
	@if python3 -c 'import tiktoken' 2>/dev/null; then \
		python3 scripts/check-skill-tokens.py; \
	else \
		echo 'SKIP token budget: run make tools to install tiktoken into $(VENV) (CI always does)'; \
	fi

## install-opencode: symlink the generated tree and skills into ~/.config/opencode, then bind models
install-opencode:
	@sh scripts/install-opencode.sh
	@sh scripts/install-opencode.sh --models

## uninstall-opencode: remove the symlinks install-opencode created
uninstall-opencode:
	@sh scripts/install-opencode.sh --uninstall

# UTILITY TARGETS

## tools: install spproof $(SPPROOF_VERSION) into $(SPPROOF_INSTALL_DIR) and the pinned Python check dependencies into $(VENV)
tools:
	@curl -sSfL https://raw.githubusercontent.com/arhuman/spproof/$(SPPROOF_VERSION)/install.sh \
		| VERSION=$(SPPROOF_VERSION) INSTALL_DIR=$(SPPROOF_INSTALL_DIR) sh
	@[ -x $(VENV)/bin/python3 ] || python3 -m venv $(VENV)
	@$(VENV)/bin/python3 -m pip install --quiet --disable-pip-version-check $(PY_DEPS)

## confirm: prompt for user confirmation before proceeding
confirm:
	@echo -n 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]
