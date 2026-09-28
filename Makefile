.DEFAULT_GOAL := help

# VARIABLES

# Generated OpenCode tree. gen writes here; check verifies it matches source.
OPENCODE_OUT ?= opencode

# Every POSIX sh script the repo runs or ships. release.sh is bash and is
# not in this set: -s sh would lint it as the wrong dialect.
SHELL_SCRIPTS = scripts/*.sh plugins/10x/hooks/*.sh \
	plugins/10x/skills/_shared/references/claim.sh \
	plugins/10x/skills/_shared/references/resolve-paths.sh

# PHONY DECLARATIONS (in alphabetical order)
.PHONY: check confirm gen help install-opencode shellcheck uninstall-opencode

# STANDARD TARGETS (in alphabetical order)

## check: run every static check, in the same order as CI
check: shellcheck
	@sh scripts/check-skill-references.sh
	@sh scripts/check-markdown-links.sh
	@sh scripts/check-skill-size.sh
	@python3 -c 'import tiktoken' 2>/dev/null \
		&& python3 scripts/check-skill-tokens.py \
		|| echo 'SKIP token budget: pip install tiktoken==0.12.0 to run it locally (CI always does)'
	@sh scripts/check-makefile-tabs.sh
	@sh scripts/check-rule-duplication.sh
	@sh scripts/check-dangling-refs.sh
	@sh scripts/check-artifact-registry.sh
	@sh scripts/check-opencode-sync.sh
	@sh scripts/check-agent-tools.sh
	@sh scripts/check-frontmatter-parses.sh
	@sh scripts/check-no-personal-paths.sh
	@sh scripts/test-hooks.sh
	@sh scripts/test-install-opencode.sh

## gen: regenerate the OpenCode commands and agents from plugin source
gen:
	@sh scripts/gen-opencode.sh $(OPENCODE_OUT)

## help: display this help message
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

## shellcheck: lint the POSIX sh scripts (warning and above); skipped with a notice when the tool is absent
shellcheck:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -s sh -S warning $(SHELL_SCRIPTS) && echo 'shellcheck: clean'; \
	else \
		echo 'SKIP shellcheck: install shellcheck 0.11.0 to run it locally (CI always does)'; \
	fi

## install-opencode: symlink the generated tree and skills into ~/.config/opencode, then bind models
install-opencode:
	@sh scripts/install-opencode.sh
	@sh scripts/install-opencode.sh --models

## uninstall-opencode: remove the symlinks install-opencode created
uninstall-opencode:
	@sh scripts/install-opencode.sh --uninstall

# UTILITY TARGETS

## confirm: prompt for user confirmation before proceeding
confirm:
	@echo -n 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]
