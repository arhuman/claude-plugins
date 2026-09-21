---
name: lang-go
description: 'Go coding best practices and patterns. Use when working with Go or Golang files: implementation, testing, refactoring, architectural review, goroutines, channels, interfaces, error handling, memory management, and API development. Not for Makefile or CI workflow authoring in a Go repo: use the `makefile` and `ci` skills.'
---

# 10x Go

This skill defines rules to write robust, maintainable, and idiomatic production Go code.

## Reference Guide

Load the relevant reference when the task involves:

| Topic | File | Load When |
|-------|------|-----------|
| Concurrency | `references/concurrency.md` | goroutines, channels, context, sync primitives, worker pools |
| Generics | `references/generics.md` | type parameters, constraints, generic data structures |
| Interface Design | `references/interfaces.md` | interface composition, functional options, io patterns, DI |
| Testing | `references/testing.md` | tests, benchmarks, fuzzing, mocking, coverage |
| Project Structure | `references/project-structure.md` | module layout, go.mod, Makefile, Dockerfile, monorepo |
| Error Handling | `references/errors.md` | sentinel errors, wrapping, custom types, GORM context |
| API Projects | `references/api.md` | gin, GORM, JWT, swagger, CORS |
| OpenAPI / Swagger | `references/openapi.md` | swaggo annotations, spec generation, Swagger UI, security schemes |
| CLI Projects | `references/cli.md` | cobra, CLI directory layout |
| REST Patterns | `references/rest-patterns.md` | URI patterns, HTTP status code, naming conventions |
| Memory & Resources | `references/memory.md` | request/response body lifecycle, goroutine limits, heap escape, sync.Pool |
| Logging & Iterators | `references/slog.md` | slog structured logging, log levels, range-over-func iterators (Go 1.23+) |
| Linting Config | `../_shared/references/golangci-minimal.yml`, `../_shared/references/golangci-strict.yml` | choosing/authoring a `.golangci.yml`; the minimal and strict tiers of the shared ladder |
| Pinned Versions | `../_shared/references/versions.md` | Go toolchain, golangci-lint, govulncheck, and GitHub Actions versions (single source of truth) |

## Architecture Principles

- Favor simplicity. Do not over-engineer the design.
- Depend on concrete types by default. Define an interface at the consumer, only when it inverts a genuine external dependency (DB, network, clock, filesystem); keep it small (ISP). Each function/type has one responsibility (SRP). See `references/interfaces.md`.
- Favor generic functions over specific ones (`hasRole(string)` instead of `hasAdminRole()` and `hasWriterRole()`).
- ALWAYS make small, atomic, incremental changes rather than big-bang rewrites.
- **Fewer packages, more files.** A package is justified by what importing it buys the caller (an independently useful capability), not by what concept it represents. Divide packages by what they provide, files by what they import. Use functions to express generalisation, files to express separation, packages to express independence. See `references/project-structure.md`.
- The reader's context budget and the materialization ladder are owned by `thinking` Simplicity First; apply them before creating any new file, type, interface, or package.
- **One verb layer, thin adapters.** Put business logic in a single service layer (`internal/<domain>`); make each entry point (CLI, HTTP, MCP, gRPC) a thin adapter that translates transport to a call on that layer. Surfaces then cannot drift in semantics. See `references/project-structure.md`.
- **Composition root, not globals.** Assemble process-wide dependencies (config, `*slog.Logger`, `*sql.DB`) once into an `App`/`Store` struct in `internal/app`; hand the built value to commands. Do not reach for package-level globals or `init()` for wiring.
- **Constructors normalize nil dependencies.** `New*` substitutes a safe default for a nil dependency (nil logger → `slog.New(slog.DiscardHandler)`, nil config → empty) instead of panicking or deferring a nil-pointer crash. See `references/interfaces.md`.

## MUST DO

- Run `gofmt` and `golangci-lint` on all generated code
- Run `go vet ./...` on all generated code (catches common correctness issues gofmt misses)
- Pass `context.Context` as the first argument to all blocking or I/O-bound functions
- Handle all errors explicitly: no naked `_` discards without justification
- Wrap errors with a package-name prefix: `fmt.Errorf("pkg: operation: %w", err)`: the prefix is the current package, lowercase, no trailing punctuation (`errorlint` enforces `%w`; `revive`/`error-strings` enforce the message shape). See `references/errors.md`
- Name sentinel errors `Err*` with a package-prefixed message (`var ErrNotFound = errors.New("memory: not found")`) and compare with `errors.Is`; `errname` enforces the `Err-` prefix / `-Error` suffix
- Write table-driven tests with `t.Run` subtests for all non-trivial functions
- Document all exported functions, types, and constants with a docstring
- Run tests with `-race` flag: `go test -race ./...`
- Always apply `http.MaxBytesReader`, drain, and close `r.Body` in HTTP handlers
- Always limit, drain, and close `resp.Body` in HTTP clients: use `io.LimitedReader{R: resp.Body, N: limit+1}` and check `limited.N == 0` to detect (and error on) overflow; never use bare `io.ReadAll(resp.Body)`
- Always close `resp.Body` on `client.Do()` error: if `resp != nil { resp.Body.Close() }` before returning
- Compile regular expressions once at package level (`var re = regexp.MustCompile(...)`): never inside functions called per request
- Cap goroutine counts with `errgroup.SetLimit` or `semaphore.NewWeighted`: never spawn unbounded goroutines over user-supplied input
- Pre-allocate slices and maps when final size is known: `make([]T, 0, n)`
- Use `errors.Is()` and `errors.As()` for error inspection
- Use `any` instead of `interface{}`
- Use type switches instead of repeated type assertions

## MUST NOT DO

- Use `panic` for recoverable errors
- Use `http.Get`, `http.Post`, or `http.DefaultClient` in production code: always create a dedicated `*http.Client` with an explicit `Timeout`
- Use `io.LimitReader` when you need truncation detection: use `io.LimitedReader{N: limit+1}` and check `N==0` instead; `io.LimitReader` silently truncates
- Create goroutines without a clear termination strategy (WaitGroup, errgroup, or channel signaling)
- Ignore context cancellation in long-running operations
- Hardcode configuration values: use environment variables or functional options
- Use reflection without measurable performance justification
- Return errors without wrapping context (`return err` alone loses the call site)
- Log AND return the same error at the same level: choose one
- Box value types into `any`/`interface{}` on hot paths without profiling justification
- Use `fmt.Sprintf` for string building in loops: use `strings.Builder` instead
- Store pointers to pooled objects outside the `sync.Pool` scope

## Coding Style

- Use PascalCase for exported types/methods, camelCase for variables
- Group imports: standard library, then third-party, then project-specific
- Package names and all exported entities must have docstrings
- Code must be self-documenting with clear, consistent naming
- Comments: default to none inside function bodies, and follow the `documentation-rules` Code Comments section. It is canonical; do not restate its rules here.
- **Keep the happy path left.** Guard clauses first: preconditions read as one paragraph of early returns, then the operation. The success flow reads top to bottom at indent zero.
- **Initialize once.** A variable acquires its identity at declaration: `customer := resolveCustomer(...)`, not `var customer Customer` followed by if/else assignment.
- **Domain ID types.** Be suspicious of functions taking several arguments of the same type. When raw string/int IDs cross function boundaries, introduce `type UserID string` style types: extra typing, no extra architecture.

## Quality Standards

- `go.mod` sets a deliberate `go` floor and a pinned `toolchain`; the two may legitimately differ. Values and rationale live in `../_shared/references/versions.md`.
- Functions must be small, focused, and easily testable.
- Every new package ships at least one `_test.go` file covering its exported surface before work is reported complete.
- **Enforce a numeric coverage gate**, not a vibe: `make cover` fails below `COVER_MIN`; the target mechanics, the default floor, and the ratchet rule (raise, never lower) live in `makefile`. As a secondary rule, no package may sit at 0% coverage in a final report; if coverage is genuinely impossible (e.g., a thin `main` package), say so explicitly.
- Dependencies must be minimal and well-justified; prefer the standard library (`log/slog`, `database/sql`, `crypto/*`, `net/http`) and pure-Go drivers before pulling a new module.
- Performance optimizations must be measured, not assumed. Profile with pprof before optimizing.
- Log at Debug level by default; log at Info level for one-time or important events (initialization, configuration).
- Never log secrets, tokens, or PII: scrub before logging.
- Use parameterized GORM queries; never concatenate user input into raw SQL.
- Run `govulncheck ./...` in CI to detect known vulnerabilities in dependencies: see the `ci` skill for the workflow that runs it (via `make audit`).

### Linting configuration

- Every Go project ships a committed `.golangci.yml` (schema `version: "2"`). Do not rely on golangci-lint defaults.
- Pick a tier from the shared ladder (`../_shared/README.md`):
  - **minimal** (`../_shared/references/golangci-minimal.yml`): small tools, libraries, early-stage code.
  - **standard** (`../makefile/references/.golangci.yml`): default; encodes the shared complexity/duplication thresholds so daily linting matches what a review measures.
  - **strict** (`../_shared/references/golangci-strict.yml`): mature services; security + error-wrapping + performance linters and ratchet-based complexity gates. Never raise a complexity gate to green a build; lower it one rung as offenders are refactored.
- Pin the golangci-lint and govulncheck versions to `../_shared/references/versions.md`; the same versions must appear in the Makefile `tools` target and the CI `lint` job so the three never drift.

## Module Preferences

-  Use `slog` for structured logging, if no existing logging framework is in place
- `github.com/stretchr/testify` and its submodules (`require`, `assert`, `suite`) for testing

## Tests

Tests are contracts with the user. See `references/testing.md` for full guidance. Key rules are in **MUST DO** above.

## Definition of Done

Before reporting work complete, all four must pass **in the working tree** (not just in-IDE diagnostics):

1. `go mod tidy`: after any import change.
2. `go build ./...`: no compile errors.
3. `go vet ./...`: no findings.
4. `go test -race ./...`: all tests pass.

In-IDE compilation, partial builds, or "it should work" inference do not count as verification. If the environment prevents running these commands, say so explicitly instead of assuming success.

## Agent Behavior

- Reduce redundancy: use tree-sitter (if available) to identify similar code patterns before generating new code.
- Use tree-sitter (if available) to analyze function complexity before refactoring.
- **Preserve test intent**: you may refactor test structure and helpers freely, but you MUST ASK for confirmation before changing test assertions, removing test cases, or altering expected behavior. Full rules, including the exact `// TODO:` marker for new cases, in `references/testing.md`.
- **Layer-dependency direction.** Before importing another internal package, ask whether it sits upstream or downstream of yours in the data flow. Upstream-to-downstream imports are fine; downstream-to-upstream creates a wrong-direction dependency even when no compile cycle results. When tempted to import sideways for a shared type, remember types live in the package that owns their lifecycle (`storage.Document`, `search.Result`): write a narrow conversion in the downstream package instead of importing sideways. Promote a type to an upstream package only when it is genuinely shared vocabulary of the data flow; never create a generic `model/`, `types/`, or ontology package as a reflex.
- **No silent design deviation.** If a stated design constraint (CONTEXT.md, an ADR, a ticket spec, an interface comment) proves hard or inconvenient to honor during implementation, STOP and surface the conflict to the caller before deviating. Silently weakening a constraint and documenting the deviation only after shipping is the worst pattern: the design loses authority, and future readers cannot distinguish intent from accident.
