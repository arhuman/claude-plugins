# Base Makefile Template

Universal Makefile skeleton applicable to any language. Merge with a language-specific template (e.g., `makefile-go.md`) to produce the final Makefile.

```makefile
.DEFAULT_GOAL := help

# ==================================================================================== #
# VARIABLES
# ==================================================================================== #

# Host port the local stack publishes; override per run: `make local API_PORT=9090`.
# Exported so `docker compose` interpolation (${API_PORT:-8080}) resolves to the
# same value `make local` prints.
API_PORT ?= 8080
export API_PORT

# ==================================================================================== #
# PHONY DECLARATIONS (in alphabetical order)
# ==================================================================================== #
.PHONY: confirm down help local up

# ==================================================================================== #
# STANDARD TARGETS (in alphabetical order)
# ==================================================================================== #

## down: stop the docker compose stack
down:
	docker compose stop

## help: display this help message
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

## local: start the stack for local development with published ports
local: down
	docker compose up -d --build
	@echo "local stack up: http://localhost:$(API_PORT)"

## up: stop, rebuild, and relaunch the docker compose stack in detached mode
up: down
	docker compose up -d --build

# ==================================================================================== #
# UTILITY TARGETS
# ==================================================================================== #

## confirm: prompt for user confirmation before proceeding
confirm:
	@echo -n 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]
```

## Composing with Language Templates

1. Start from this base skeleton
2. Merge targets from the relevant language template (e.g., `makefile-go.md`)
3. Add merged targets to the `.PHONY` declaration in alphabetical order
4. Add project-specific targets in a dedicated section at the end

## Adding Project-Specific Targets

Add a `PROJECT-SPECIFIC TARGETS` section at the end. Custom targets must be:
- Alphabetically ordered within the section
- Added to the `.PHONY` declaration
- Documented with a `## target: description` comment

Example:
```makefile
# ==================================================================================== #
# PROJECT-SPECIFIC TARGETS
# ==================================================================================== #

## deploy_test: deploy to test environment
deploy_test: confirm
	docker compose -f docker-compose-test.yml up -d
```
