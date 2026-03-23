---
name: lang-go
description: Go coding best practices and patterns. Use when working with Go or Golang files: implementation, testing, refactoring, architectural review, goroutines, channels, interfaces, error handling, memory management, and API development.
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

## Architecture Principles

- Favor simplicity. Do not over-engineer the design.
- Depend on interfaces, not concrete types (DI). Prefer small, single-method interfaces (ISP). Each function/type has one responsibility (SRP).
- Favor generic functions over specific ones (`hasRole(string)` instead of `hasAdminRole()` and `hasWriterRole()`).
- ALWAYS make small, atomic, incremental changes rather than big-bang rewrites.
- Introduce interfaces when needed to enable loose coupling.

## MUST DO

- Run `gofmt` and `golangci-lint` on all generated code
- Run `go vet ./...` on all generated code (catches common correctness issues gofmt misses)
- Pass `context.Context` as the first argument to all blocking or I/O-bound functions
- Handle all errors explicitly — no naked `_` discards without justification
- Wrap errors with `fmt.Errorf("operationName: %w", err)` — see `references/errors.md`
- Write table-driven tests with `t.Run` subtests for all non-trivial functions
- Document all exported functions, types, and constants with a docstring
- Run tests with `-race` flag: `go test -race ./...`
- Always apply `http.MaxBytesReader`, drain, and close `r.Body` in HTTP handlers
- Always limit, drain, and close `resp.Body` in HTTP clients — use `io.LimitedReader{R: resp.Body, N: limit+1}` and check `limited.N == 0` to detect (and error on) overflow; never use bare `io.ReadAll(resp.Body)`
- Always close `resp.Body` on `client.Do()` error: if `resp != nil { resp.Body.Close() }` before returning
- Compile regular expressions once at package level (`var re = regexp.MustCompile(...)`) — never inside functions called per request
- Cap goroutine counts with `errgroup.SetLimit` or `semaphore.NewWeighted` — never spawn unbounded goroutines over user-supplied input
- Pre-allocate slices and maps when final size is known: `make([]T, 0, n)`
- Use `errors.Is()` and `errors.As()` for error inspection
- Use `any` instead of `interface{}`
- Use type switches instead of repeated type assertions

## MUST NOT DO

- Use `panic` for recoverable errors
- Use `http.Get`, `http.Post`, or `http.DefaultClient` in production code — always create a dedicated `*http.Client` with an explicit `Timeout`
- Use `io.LimitReader` when you need truncation detection — use `io.LimitedReader{N: limit+1}` and check `N==0` instead; `io.LimitReader` silently truncates
- Create goroutines without a clear termination strategy (WaitGroup, errgroup, or channel signaling)
- Ignore context cancellation in long-running operations
- Hardcode configuration values — use environment variables or functional options
- Use reflection without measurable performance justification
- Return errors without wrapping context (`return err` alone loses the call site)
- Log AND return the same error at the same level — choose one
- Box value types into `any`/`interface{}` on hot paths without profiling justification
- Use `fmt.Sprintf` for string building in loops — use `strings.Builder` instead
- Store pointers to pooled objects outside the `sync.Pool` scope

## Coding Style

- Use PascalCase for exported types/methods, camelCase for variables
- Group imports: standard library, then third-party, then project-specific
- Package names and all exported entities must have docstrings
- Code must be self-documenting with clear, consistent naming
- Avoid nested logic — follow the "happy path" principle

## Quality Standards

- Minimum Go version: 1.22+
- Functions must be small, focused, and easily testable.
- Dependencies must be minimal and well-justified.
- Performance optimizations must be measured, not assumed. Profile with pprof before optimizing.
- Log at Debug level by default; log at Info level for one-time or important events (initialization, configuration).
- Never log secrets, tokens, or PII — scrub before logging.
- Use parameterized GORM queries; never concatenate user input into raw SQL.
- Run `govulncheck ./...` in CI to detect known vulnerabilities in dependencies.

## Module Preferences

- `go.uber.org/zap` for structured logging
- `github.com/stretchr/testify` and its submodules (`require`, `assert`, `suite`) for testing

## Tests

Tests are contracts with the user. See `references/testing.md` for full guidance. Key rules are in **MUST DO** above.

## Agent Behavior

- Reduce redundancy — use tree-sitter (if available) to identify similar code patterns before generating new code.
- Use tree-sitter (if available) to analyze function complexity before refactoring.
- **Preserve test intent**: you may refactor test structure and helpers freely, but you MUST ASK for confirmation before changing test assertions, removing test cases, or altering expected behavior.
- When adding new test cases: add with a `// TODO: uncomment and validate` comment and notify the user.
