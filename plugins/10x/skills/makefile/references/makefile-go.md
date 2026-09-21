# Go Makefile Targets

Go-specific targets to merge into the base Makefile template. When composing, add these targets in alphabetical order among the existing standard targets.

## Variables

`?=` on every tunable so CI or a caller can override it; `:=` for computed-once
values. Keep the tool versions equal to `../../_shared/references/versions.md`.

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

# Version metadata injected via ldflags. VERSION_PKG is the package that declares
# the Version/GitCommit/BuildDate vars (e.g. main, or internal/version).
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

When copying, replace `progname` (and `MAIN_PACKAGE` if the entry point differs)
with the project's real names: the finished Makefile must not contain `progname`.

These three lines are only half the contract: they stamp the two build paths
that run a linker, and the package they target has to cover the third on its
own. `./version-go.md` owns that half, with the per-path table and the fallback
it requires; a Makefile merged without it stamps correctly and still ships a
binary that misreports its own version.

`VERSION` needs nothing extra for the `v` prefix: `git describe` already emits
it. Only goreleaser strips it and has to put it back, which is why that rule
lives with the goreleaser config rather than here.

Add the Go targets to `.PHONY` when merging into the base skeleton:

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

## fulltest: every test the repo owns: long units, race, coverage, and the
## e2e / db-backed suites when a compose test overlay exists. This is the
## phase-closing gate, run once per phase, never in the red/green iteration.
fulltest:
	go test -race -cover ./...
	@if grep -qE '^test-e2e:' Makefile 2>/dev/null; then $(MAKE) test-e2e; fi

## release: cut and publish a release (derive version, changelog, tag, push)
release:
	@./scripts/release.sh

## run: build and run the binary locally
run: build
	./bin/$(BINARY_NAME)

## test: short unit tests only, seconds on a warm cache: the red/green loop.
## No -race and no -cover here on purpose: each adds an instrumented rebuild
## of every touched package, which turns a 30s suite into minutes on every
## iteration. Both run in fulltest, once per phase.
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

`make release` delegates to `scripts/release.sh` (template: `release.sh`, beside this file)
rather than re-running `test build audit`, which the gate below already covers.
Copy the reference verbatim into the repo and mark it executable:

```sh
mkdir -p scripts
cp release.sh scripts/release.sh   # from this skill's references/
chmod +x scripts/release.sh
```

The script is language-agnostic (its only project hook is the `make ci` gate):
it derives the next version from the Conventional Commits since the last `v*`
tag (feat -> minor, fix/other -> patch, `!`/`BREAKING CHANGE` -> major, capped
to minor while on 0.x), prints it as an editable default, runs `make ci`, stamps
`CHANGELOG.md` (promotes `[Unreleased]` to a dated version heading), then commits,
tags and pushes. Pushing the `v*` tag is what triggers `release.yml` -> goreleaser,
so the human never types a version by hand unless they want to override it. The
`release.script` conformance check (`standard.yml`) verifies both the script and
the wired `release` target are present.

## Coverage gate is a ratchet

`cover` fails the build when total coverage drops below `COVER_MIN` (default 80).
Raise `COVER_MIN` as coverage improves; never lower it to make a red build pass.
To count the production code a test *exercises* rather than only the package it
lives in, add `-coverpkg=./...` to the `cover` recipe. `audit` depends on `cover`
so the gate runs as part of the quality pass and in CI.

## Multi-module repos (go.work)

For a workspace with several modules, iterate them in dependency order and fail
fast on the first error rather than assuming a single root module:

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

Use `.golangci.yml` (beside this file) as the **standard** tier golangci-lint v2 configuration for Go projects. It encodes the shared complexity/duplication thresholds of the tier ladder in `../../_shared/README.md` (`gocyclo`, `gocognit`, `funlen`, `nestif`, `dupl`), so projects scaffolded from this template enforce day-to-day what a review measures.

For a lighter or heavier gate, use the other tiers of the shared ladder: `../../_shared/references/golangci-minimal.yml` (small tools/libraries) or `../../_shared/references/golangci-strict.yml` (mature services). See `../../_shared/README.md`.

Pin the golangci-lint and govulncheck versions in the `tools` target above to `../../_shared/references/versions.md`: the same versions must appear in the CI `lint` job so the Makefile, the config, and CI never drift.

## Standard conformance gate

Conformance is checked by the global runner in the `conform` skill, not a
per-repo `make` target: the runner lives once in the plugin and runs against any
repo, so the Makefile carries no copy of it. Diagnose with `/check_conform` and
apply fixes with `/make_conform`. To gate in CI, fetch the runner at job time
(see the `conform` skill's "Enforce in CI" section) rather than committing
`scripts/conform.sh`.
