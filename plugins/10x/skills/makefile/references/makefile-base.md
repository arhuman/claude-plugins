# Base Makefile Template

Merge this skeleton with requested language-specific targets.

```makefile
.DEFAULT_GOAL := help

# VARIABLES

# Export so Compose and the printed URL use the same overridable port.
API_PORT ?= 8080
export API_PORT

# PHONY DECLARATIONS (in alphabetical order)
.PHONY: confirm down help local up

# STANDARD TARGETS (in alphabetical order)

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

# UTILITY TARGETS

## confirm: prompt for user confirmation before proceeding
confirm:
	@echo -n 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]
```

## Composing with Language Templates

Merge language targets alphabetically and update `.PHONY`.

## Adding Project-Specific Targets

Append a `PROJECT-SPECIFIC TARGETS` section: alphabetized targets, `.PHONY` declarations and `## target: description` comments. Gate destructive actions on `confirm`.
