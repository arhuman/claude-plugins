# Standard Go Project Makefile Template

```makefile
BINARY_NAME=my-api

# ==================================================================================== #
# VARIABLES
# ==================================================================================== #
# Use a specific Dockerfile for local builds to inject CI-only layers
compose_build: export DOCKERFILE = Dockerfile_localbuild
deploy_test: export DOCKERFILE = Dockerfile_localbuild
deploy_preprod: export DOCKERFILE = Dockerfile_localbuild

# ==================================================================================== #
# PHONY DECLARATIONS (in alphabetical order)
# ==================================================================================== #
.PHONY: audit build clean compose_build compose_run compose_stop confirm doc help local release run test tidy tools

# ==================================================================================== #
# STANDARD TARGETS (in alphabetical order)
# ==================================================================================== #

## audit: run all quality control checks (vet, staticcheck, govulncheck, revive, test)
audit: tools
	@echo "Running quality control checks..."
	go mod verify
	go vet ./...
	staticcheck -checks=all,-ST1000,-U1000 ./...
	govulncheck ./...
	revive ./...
	go test -race -buildvcs -vet=off ./...

## build: build the Go binary for a Linux environment
build:
	CGO_ENABLED=0 GOOS=linux GOFLAGS="-ldflags=-s -ldflags=-w" go build -o server ./cmd/api/

## clean: remove the binary and clean Go cache
clean:
	go clean
	rm -f ${BINARY_NAME} server

## compose_build: build the docker image using docker compose
compose_build: build
	docker compose build

## compose_run: stop, build, and relaunch the docker compose stack in detached mode
compose_run: compose_stop compose_build
	docker compose up -d

## compose_stop: stop the docker compose stack
compose_stop:
	docker compose stop

## doc: generate API documentation using swag
doc: tools
	swag init -g cmd/api/main.go

## help: display this help message
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

## local: build the binary and launch the local docker compose environment
local: build compose_run

## release: run the full release pipeline (test, build, audit)
release: test build audit

## run: build and run the binary locally
run: build
	./${BINARY_NAME}

## test: run all tests with verbose output
test:
	go test -v ./...

## tidy: format Go code and tidy the module file
tidy:
	go fmt ./...
	go mod tidy -v

## tools: install required Go development tools
tools:
	@echo "Installing Go tools..."
	@go install github.com/swaggo/swag/cmd/swag@latest
	@go install honnef.co/go/tools/cmd/staticcheck@latest
	@go install golang.org/x/vuln/cmd/govulncheck@latest
	@go install github.com/mgechev/revive@latest
	@echo "Tools installed in $(shell go env GOBIN || go env GOPATH)/bin"

# ==================================================================================== #
# UTILITY TARGETS
# ==================================================================================== #

## confirm: prompt for user confirmation before proceeding
confirm:
	@echo -n 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]
```

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
deploy_test: confirm build
	docker compose -f docker-compose-test.yml up -d
```
