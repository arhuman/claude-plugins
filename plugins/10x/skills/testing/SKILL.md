---
name: testing
description: 'Use for unit, integration, E2E, performance/security tests, strategies, coverage, defects, test failures, manual QA and CI test pipelines. Strict red-green-refactor belongs to tdd; a loop bugfix phase keeps its single failing test inline.'
---

# Testing contracts

## Core Workflow

Define scope, plan through **[Test]**, **[Perf]**, **[Security]** perspectives, implement assertions, execute, report actionable findings.

Done only when every planned case has pass/fail/skip-with-reason evidence, the working-tree suite is green (`go test -race ./...` or equivalent), and severity findings refer only to actual runs. Never invent passes.

## Constraints

- Cover happy/error paths and every input surface's empty, duplicate, concurrent, stale, missing, hostile, partial shapes.
- Go: table-driven `t.Run`, race detector for all tests. TypeScript: `describe`/`it`.
- Override test DB host/port; poll live-server health before integration tests. Never use production data/credentials/connections.
- Measure coverage with `make cover` or `go test -coverprofile=coverage.out ./...`.
- No order dependence, ignored flakes, implementation-detail assertions, or committed debug code/skipped tests.

## Output Templates

Plans include scope/approach, cases with expected outcomes, coverage analysis, Critical/High/Medium/Low findings, specific fixes. Reports follow [test-reports](references/test-reports.md).

## Reference Guide

Load only for the relevant work; reference-project conventions are examples to adapt, not universal layouts.

| Work | Contract |
|---|---|
| Go/Angular unit tests | [unit-testing](references/unit-testing.md) |
| API/JSON fixtures | [integration-testing](references/integration-testing.md) |
| New Playwright/existing Cypress | [e2e-testing](references/e2e-testing.md) |
| Real DBs, readiness, fulltest | [docker-db-testing](references/docker-db-testing.md) |
| Load/stress/spike/soak | [performance-testing](references/performance-testing.md) |
| Security test authoring | [security-testing](references/security-testing.md) |
| Manual QA, metrics, release gates | [qa-methodology](references/qa-methodology.md) |
| Test-first work | [tdd-iron-laws](references/tdd-iron-laws.md) |
| Mock/test quality review | [testing-anti-patterns](references/testing-anti-patterns.md) |

TDD/anti-pattern material adapted from [obra/superpowers](https://github.com/obra/superpowers), Jesse Vincent (@obra), MIT License.
