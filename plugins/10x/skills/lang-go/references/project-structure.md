# Project Structure and Module Management

## Standard Directory Layout

Available slots, created only as needed:

```text
cmd/<binary>/main.go       binary entry points
internal/app/             composition root
internal/<domain>/        business logic and persistence files
internal/api/             HTTP adapter, if independently useful
internal/testutil/        shared fixtures, goldens, fakes
pkg/                      intentionally public library API only
api/openapi.yaml, proto/  contracts (proto under api/)
configs/                  config templates
deployments/              Docker, Kubernetes, Terraform
scripts/                  build, migration, maintenance
test/                     integration data/helpers
docs/                     architecture and ADRs
go.mod, go.sum, Makefile, README.md
```

## The Layout Is a Ceiling, Not a Default

Start with one package per domain and split files by imports: `customer.go` (stdlib logic), `customer_store.go` (SQL/GORM), `customer_email.go` (SMTP). Functions express generalization, files separation, packages independence. Create `api/`, `service/`, `repository/` only when importing each buys an independently useful capability. Collapse forwarding-only layers. `pkg/models` is only for genuinely public vocabulary; [type ownership](../SKILL.md#agent-behavior) still applies.

## internal/: Enforced Visibility Boundary

Put non-public code under `internal/`; Go restricts imports to the tree rooted at its parent. Use `pkg/` only for intentional external consumers.

## Composition Root (internal/app)

Assemble config, logger, DB and domain services once into `App`/`Store` in `internal/app`. Pass the built value down; no dependency globals or `init()` wiring. Commands receive it, never construct their own DB/logger. All CLI, HTTP, MCP and gRPC entry points translate transport into calls on one business-logic layer (`internal/<domain>`).

Keep executable logic testable through `run`:

```go
func main() {
    if err := run(context.Background(), os.Args[1:], os.Stdout); err != nil {
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }
}
```

Implement `run(ctx context.Context, args []string, out io.Writer) error` for parsing, construction and execution. Skip this wrapper if main already trivially delegates to Cobra `Execute()` or `app.Run()`.

## go.mod Basics

When editing module/compiler versions, load [pinned versions](../../_shared/references/versions.md). `go` is the consumer compatibility floor, raised deliberately; `toolchain` is the build/test compiler, tracking security patches. Document an otherwise confusing gap. Use `replace module => ../local-copy` for local development and `retract vX.Y.Z` with a reason for a bad release.

## Module Commands

Select by task: `go mod init <module>` initializes; `go mod download` caches; `go mod verify` verifies downloads; `go mod vendor` supports offline builds; `go get pkg@version` pins an update; `go get -u ./...` updates minor/patch dependencies; `go mod why pkg` explains inclusion. Import-change tidy is in the [completion gate](../SKILL.md#definition-of-done).

## Monorepo with go.work

When repo modules reference each other, use workspaces: `go work init ./services/api ./services/worker`, `go work use ./shared/models`, then `go work sync`. The generated `go.work` lists these paths in `use (...)`; choose its Go version from the shared version policy, not a stale template.

## Build Tags

Place `//go:build` before `package`, separated by a blank line. Use `linux && amd64`, `linux || darwin`, `!windows`, or `integration` as needed. Run tagged integration tests with `go test -tags=integration ./...`; variant gates live in [testing](testing.md#build-tag-matrix).

## Makefile

When authoring Go targets, load [makefile](../../makefile/SKILL.md) and its [Go template](../../makefile/references/makefile-go.md). It owns build/test/lint/fmt/clean/run/help, generation, cross-compilation, Docker targets and numeric coverage mechanics. Select the correct `cmd/<binary>`; use GOOS/GOARCH for required target variants rather than duplicating an independent template here.

## Dockerfile Multi-Stage Build

When containerizing Go, load [docker](../../docker/SKILL.md) and its [Go API Dockerfile](../../docker/references/go-api-dockerfile.md). Use the correct command path, cache dependency downloads from go.mod/go.sum before source copies, and match CGO/driver needs. The canonical template owns stages, runtime image, certificates/timezone data, ports and startup.

## Version Injection via ldflags

When exposing build metadata, load [canonical Go version template](../../makefile/references/version-go.md) and [Go build targets](../../makefile/references/makefile-go.md). Keep `-X` paths aligned with the actual Go package; expose version, commit, build time and runtime Go version through the canonical API rather than a second variable/template contract.

## go generate and Tool Dependencies

Pin generator dependencies in go.mod through build-excluded `tools.go` blank imports (e.g. mockery, stringer, swag):

```go
//go:build tools

package tools

import _ "github.com/vektra/mockery/v2"
```

Put `//go:generate mockery --name=UserRepository --output=./mocks` beside the generated concern; execute `go generate ./...`.

## Configuration Management

Use environment variables plus typed config structs, or functional options; no hardcoded configuration. Check required values with `os.LookupEnv` and fail fast. Group server host/port/read/write timeouts and database URL/open/idle connection limits in config. Parse typed values explicitly and supply defaults only for optional settings.

## Quick Reference

Gate: justify each new package's independent caller value, verify one composition root and one business layer, and load canonical build/config references for the surfaces changed.
