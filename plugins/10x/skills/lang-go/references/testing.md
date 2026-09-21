# Testing

## Tests as User Contracts

Ask explicit user approval before changing assertions, removing cases or altering expected behavior; explain behavior changes first. Freely refactor structure/helpers/setup while preserving intent. Mark new cases with `// TODO: uncomment and validate with user` and notify the user.

## Table-Driven Tests

Require table-driven `t.Run` subtests for non-trivial functions and multiple input/output scenarios. Give each case a name, inputs, expected result and error expectation; check errors before success values. Every new package needs at least one `_test.go` covering its exported surface before completion.

## Parallel Subtests

Use `t.Parallel()` for independent, concurrent-safe cases; isolate their state.

## Test Helpers

Call `t.Helper()` so failures identify callers. Register resource teardown with `t.Cleanup`; prefer testify `require.NoError` over custom wrappers.

## testify Usage

Prefer `github.com/stretchr/testify`: `require` for fatal prerequisites, `assert` for non-fatal checks.

### testify/suite for shared setup

For shared setup use `suite.Suite`, `SetupTest`, suite assertions and `suite.Run(t, new(RepoTestSuite))`.

## Mocking with Interfaces

Apply [interface eligibility](interfaces.md#when-not-to-define-an-interface) first. Prefer manual mocks for small interfaces, mockery for large ones; record boundary calls and inject failure behavior as required by the contract.

## Benchmarking

Exclude fixture setup with `b.ResetTimer()`, report allocations with `b.ReportAllocs()`, compare approaches with `b.Run`, and use `b.RunParallel`/`pb.Next()` for concurrency. Execute `go test -bench=. -benchmem ./...`.

## Fuzzing (Go 1.18+)

Seed representative and empty inputs with `f.Add`, then `f.Fuzz`. Invalid inputs may return normally; successful parsing must satisfy properties such as format/parse round-trip equality. Run `go test -fuzz=FuzzParseQuery -fuzztime=30s` for the target.

## Race Detector

CI always runs with `-race`; the whole-tree completion command is owned by [Definition of Done](../SKILL.md#definition-of-done). For diagnosis: `go test -race -run TestConcurrentAccess ./internal/cache/...`.

## Coverage

Generate atomic counts with `go test -covermode=atomic -coverprofile=coverage.out ./...` (atomic is required with race instrumentation). Use `-coverpkg=./...` to measure production packages exercised across package boundaries. Inspect with `go tool cover -html=coverage.out` or `-func=coverage.out`.

Require numeric `make cover` gating through `COVER_MIN`; [makefile-go](../../makefile/references/makefile-go.md) owns the shell, default floor and raise-only ratchet. Do not write a second gate. No package at 0% in the final report unless genuinely impossible (e.g. thin main); explicitly report that exception.

## Golden Files

For complex rendered output, store expected files in `testdata/` and regenerate only via an `-update` flag. Compare deterministic projections for structured data rather than raw dumps.

```go
var updateGolden = flag.Bool("update", false, "update golden files")

func TestRenderReport(t *testing.T) {
    got := RenderReport(ReportData{Title: "Q1"})
    golden := filepath.Join("testdata", "report.golden")
    if *updateGolden {
        require.NoError(t, os.WriteFile(golden, []byte(got), 0o644))
    }
    want, err := os.ReadFile(golden)
    require.NoError(t, err)
    assert.Equal(t, string(want), got)
}
```

Run `go test -run TestRenderReport -update` only subject to the assertion-approval rule.

## Build-Tag Matrix

When build tags select implementations (embedded/external, CGO/pure-Go), give each a real build and test. Put implementations behind opposite tags (`//go:build embed`, `//go:build !embed`), with shared tests compiling under both. CI runs default `go test ./...` and `go test -tags embed ./...`; include every actual variant. Test no-op/stub variants for inert behavior too.

## Shared Helpers (internal/testutil)

Share fixtures, golden loaders, fake clocks and in-memory fakes across packages via `internal/testutil`; follow the helper lifecycle rule above instead of per-test cleanup copies.

## Short Tests

Guard external-resource tests (DB, container, network) and tests taking roughly over 100ms with `if testing.Short() { t.Skip("requires external resources or slow computation") }`. `go test -short ./...` must be fast unit-only; `go test ./...` includes all untagged tests.

## Integration Tests

Add `//go:build integration` plus a blank line before package when tests need a separate build step or CI environment; keep the short-mode guard too. Run `go test -tags=integration ./...`.

## HTTP Handler Testing

Test Gin without a live server: `httptest.NewRecorder`, `httptest.NewRequest`, required auth headers, `router.ServeHTTP(w, req)`, then assert status and decoded body.

## Environment Variables in Tests

Use `t.Setenv` for automatically restored environment values.

## Quick Reference

For focused runs: `go test -v -run TestName`; disable caching with `-count=1`. Gate: approved behavioral assertions, new-package coverage, required build variants, and actual race/coverage command results.
