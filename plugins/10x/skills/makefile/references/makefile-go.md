# Go Makefile Targets

Merge alphabetically into the base standard targets.

## Variables

Tunables use `?=`, computed-once values `:=`; shared versions own tool pins.

```makefile
GOOS := $(shell go env GOOS)
MAIN_PACKAGE ?= ./cmd/api/

ifeq ($(GOOS),windows)
BINARY_NAME := progname.exe
else
BINARY_NAME := progname
endif

# Quality gates (ratchets: raise over time, never lower to green a build)
COVER_MIN  ?= 80
LINE_LIMIT ?= 500

# Pinned tool versions: must match ../../_shared/references/versions.md
GOLANGCI_VERSION    ?= v2.13.2
GOVULNCHECK_VERSION ?= v1.7.0

# VERSION_PKG declares Version/GitCommit/BuildDate (main or internal/version).
VERSION_PKG ?= main
VERSION    ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT     ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
# Committer date, not wall-clock: keeps rebuilds of the same commit byte-identical.
BUILD_DATE ?= $(shell git log -1 --format=%cI 2>/dev/null || echo unknown)
LDFLAGS := -s -w \
	-X '$(VERSION_PKG).Version=$(VERSION)' \
	-X '$(VERSION_PKG).GitCommit=$(COMMIT)' \
	-X '$(VERSION_PKG).BuildDate=$(BUILD_DATE)'
```

Replace `progname` and entry point with project names. Load `version-go.md` for matching variables and go-install fallback; `git describe` already keeps `v` (goreleaser needs explicit prefix). Merge into `.PHONY`:

```makefile
.PHONY: audit build checklen ci clean cover doc fulltest release run test tidy tools
```

## Targets

```makefile
## audit: run quality control checks (mod verify, lint, vuln scan, coverage gate)
audit: cover
	@which golangci-lint > /dev/null || $(MAKE) tools
	@which govulncheck > /dev/null || $(MAKE) tools
	go mod verify
	golangci-lint run ./...
	govulncheck ./...

## build: build the static Go binary with version metadata
# CGO_ENABLED=0 => static binary (runs in scratch/alpine); -trimpath => reproducible paths; -s -w => strip debug info
build:
	CGO_ENABLED=0 go build -trimpath -ldflags="$(LDFLAGS)" -o bin/$(BINARY_NAME) $(MAIN_PACKAGE)

## checklen: fail if any non-generated .go file exceeds LINE_LIMIT lines
checklen:
	@fail=0; \
	for f in $$(git ls-files '*.go' | grep -Ev '_test\.go$$|\.gen\.go$$|\.pb\.go$$'); do \
		n=$$(wc -l < "$$f"); \
		if [ "$$n" -gt "$(LINE_LIMIT)" ]; then echo "$$f: $$n lines > $(LINE_LIMIT)"; fail=1; fi; \
	done; \
	exit $$fail

## ci: run the full local CI pipeline (tidy, audit, fulltest)
ci: tidy audit fulltest

## clean: remove the binary and clean Go cache
clean:
	go clean
	rm -f bin/$(BINARY_NAME) coverage.out

## cover: run tests with coverage and fail below COVER_MIN
cover:
	go test -covermode=atomic -coverprofile=coverage.out ./...
	@go tool cover -func=coverage.out | awk '/^total:/ {print "coverage: " $$3}'
	@total=$$(go tool cover -func=coverage.out | awk '/^total:/ {print $$3}' | tr -d '%'); \
	awk -v t="$$total" -v min="$(COVER_MIN)" 'BEGIN { if (t+0 < min+0) { printf "FAIL: coverage %.1f%% < %d%%\n", t, min; exit 1 } }'

## doc: generate API documentation using swag
doc: tools
	swag init -g cmd/api/main.go

## fulltest: phase-closing gate: long units, race, coverage, available E2E/DB suites
fulltest:
	go test -race -cover ./...
	@if grep -qE '^test-e2e:' Makefile 2>/dev/null; then $(MAKE) test-e2e; fi

## release: cut and publish a release (derive version, changelog, tag, push)
release:
	@./scripts/release.sh

## run: build and run the binary locally
run: build
	./bin/$(BINARY_NAME)

## test: short units for red/green; race/coverage run in fulltest once per phase
test:
	go test -short ./...

## tidy: format Go code and tidy the module file
tidy:
	go fmt ./...
	go mod tidy -v

## tools: install pinned Go development tools
tools:
	@echo "Installing Go tools..."
	@go install github.com/swaggo/swag/cmd/swag@latest
	@go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(GOLANGCI_VERSION)
	@go install golang.org/x/vuln/cmd/govulncheck@$(GOVULNCHECK_VERSION)
	@echo "Tools installed in $(shell go env GOBIN || go env GOPATH)/bin"
```

## Release automation

Copy adjacent `release.sh` verbatim and make executable; `make release` delegates to it:

```sh
mkdir -p scripts
cp release.sh scripts/release.sh   # from this skill's references/
chmod +x scripts/release.sh
```

Contract: derive editable version from commits since last `v*` (feat minor, fix/other patch, breaking major capped to minor on 0.x); run `make ci`; promote `[Unreleased]` to dated CHANGELOG heading; commit/tag/push. The tag triggers release.yml/goreleaser. `release.script` in `standard.yml` checks script + wiring.

## Coverage gate is a ratchet

Coverage floor is 80 by default; raise, never lower to pass. Add `-coverpkg=./...` to measure exercised production packages. `audit` depends on `cover` locally and in CI.

## Multi-module repos (go.work)

Iterate modules in dependency order; fail fast:

```makefile
MODULES ?= ./proto ./client ./server

## test-all: run tests across every module in the workspace
test-all:
	@for m in $(MODULES); do \
		echo "==> $$m"; \
		(cd $$m && go test -race ./...) || exit 1; \
	done
```

## Reference Configuration

Use adjacent `.golangci.yml` for standard-tier v2 complexity/duplication gates. For small tools/libraries load `../../_shared/references/golangci-minimal.yml`; mature services use `golangci-strict.yml` there. Read `../../_shared/README.md` for thresholds and `../../_shared/references/versions.md` for pins; Makefile and CI must match.

## Standard conformance gate

Use global `conform`: `/check_conform` to diagnose, `/make_conform` to fix. For CI load its “Enforce in CI” section and fetch at job time; no per-repo target or committed `scripts/conform.sh` copy.
