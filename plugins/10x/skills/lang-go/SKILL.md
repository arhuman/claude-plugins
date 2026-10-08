---
name: lang-go
description: 'Go coding best practices and patterns. Use when working with Go or Golang files: implementation, testing, refactoring, architectural review, goroutines, channels, interfaces, error handling, memory management, and API development. Not for Makefile or CI workflow authoring in a Go repo: use the `makefile` and `ci` skills.'
---

# 10x Go

## Reference Guide

Load the owner for each changed concern; apply its gates:

| Concern | Owner |
|---------|-------|
| Context, goroutine lifecycle/caps, channels, sync | [concurrency](references/concurrency.md) |
| Type parameters, constraints, collections | [generics](references/generics.md) |
| Interfaces, DI, nil defaults, options, io | [interfaces](references/interfaces.md) |
| Test contracts, coverage, benchmarks, fuzzing | [testing](references/testing.md) |
| Packages, composition root, config, modules/builds | [project structure](references/project-structure.md) |
| Wrapping, sentinels, custom errors, GORM context | [errors](references/errors.md) |
| Gin, GORM, JWT, CORS, server setup | [API](references/api.md) |
| swaggo annotations, generation, UI, security | [OpenAPI](references/openapi.md) |
| Cobra, CLI layout/output | [CLI](references/cli.md) |
| URIs, HTTP semantics, status, caching | [REST](references/rest-patterns.md) |
| HTTP bodies, allocation, pooling | [memory](references/memory.md) |
| Structured logging, Go 1.23+ iterators | [slog](references/slog.md) |

## Architecture Principles

- Make small, atomic, incremental changes. Keep functions/types focused, small and testable; avoid over-engineering.
- Prefer parameterized behavior (`hasRole(string)`) over role-specific copies.
- Before adding files, types, interfaces or packages, apply `thinking` Simplicity First and its materialization ladder. Package boundaries and interfaces are governed by the references above.
- Prefer standard library (`log/slog`, `database/sql`, `crypto/*`, `net/http`) and pure-Go drivers; justify every added dependency.
- Profile with pprof before optimizing. Reflection requires measurable performance justification.

## Coding Style

- PascalCase exports, camelCase variables; clear, consistent names. Imports: standard library, third-party, project.
- Document packages and every exported function, type, method and constant. Function-body comments default to none; `documentation-rules` Code Comments is canonical.
- Guard clauses first; keep the success path unindented. Initialize a variable's identity at declaration rather than later if/else assignment.
- Use domain ID types (`type UserID string`) when raw string/int IDs cross function boundaries, especially several same-type parameters.
- Use `any`, not `interface{}`. Assertion rules belong to [interfaces](references/interfaces.md#type-assertions-and-type-switches).

## Quality Standards

- Pin a deliberate `go` floor and `toolchain` per [versions](../_shared/references/versions.md); they may differ.
- Run `gofmt` and `golangci-lint` on generated code.
- Use parameterized GORM queries, never user-input concatenation.
- CI must run `govulncheck ./...` through `make audit`; load [ci](../ci/SKILL.md) for workflow changes.

### Linting configuration

Commit `.golangci.yml`, schema `version: "2"`; never rely on defaults. Select from the [shared ladder](../_shared/README.md):
- [minimal](../_shared/references/golangci-minimal.yml): small tools, libraries, early-stage code.
- [standard](../makefile/references/.golangci.yml): default; shared complexity/duplication thresholds.
- [strict](../_shared/references/golangci-strict.yml): mature services; security, wrapping, performance and ratcheted complexity. Never raise a complexity gate to pass; lower a rung as offenders are refactored.

Pin golangci-lint/govulncheck to [versions](../_shared/references/versions.md); Makefile `tools` and CI `lint` must agree with it.

When a prebuilt analyzer rejects the module because it was built with an older Go, run it through the module's toolchain instead of installing anything: `go run <tool>@<pinned version>` from the module root (`GOTOOLCHAIN=auto` selects the go.mod toolchain), or `go tool <name>` when go.mod declares it. Falling back to another prebuilt analyzer (staticcheck) fails the same way. If the toolchain cannot be fetched, report the analysis as not run; a source read does not replace it.

## Module Preferences

Logging is owned by [slog](references/slog.md); testify (`require`, `assert`, `suite`) by [testing](references/testing.md).

## Tests

Load [testing](references/testing.md) before adding/changing tests, including its user-approval and exact TODO-marker requirements. It owns new-package tests, coverage and exceptions.

## Definition of Done

Require working-tree results, not IDE diagnostics or inference:
1. After import changes: `go mod tidy`.
2. `go build ./...` with no compile errors.
3. `go vet ./...` with no findings.
4. `go test -race ./...` with all tests passing.

If blocked by the environment, report the unrun command explicitly.

## Agent Behavior

- If tree-sitter is available, find similar patterns before generating code and analyze complexity before refactoring.
- Before internal imports, check data-flow direction: upstream may import downstream, never reverse, even without a compile cycle. Types belong to their lifecycle owner (`storage.Document`, `search.Result`); use narrow downstream conversions instead of sideways imports. Promote only genuinely shared upstream vocabulary; no reflexive `model/`, `types/` or ontology package.
- If CONTEXT.md, an ADR, ticket or interface constraint is difficult to honor, STOP and surface the conflict before deviating. Do not weaken it silently and disclose only afterward.
