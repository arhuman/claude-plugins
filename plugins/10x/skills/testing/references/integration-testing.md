# Integration Testing

## Go: API Integration Tests

Use a real Compose-started server after health readiness. Reference layout: `internal/api/api_test.go`, expected JSON in `internal/api/testdata/*.json`; adapt to the project. Follow the canonical [Go fixture guidance](../../lang-go/references/testing.md#fixtures).

### HTTP Request Helper

Share request construction with JSON content type and caller-supplied authentication headers (`X-Krakend-*` in the reference project). Return request/transport errors; close response bodies and check status and body-read errors before comparisons. Do not copy local example hosts or TLS bypasses into project defaults.

### JSON Fixture Comparison

Compare actual and expected JSON structurally, with `github.com/wI2L/jsondiff` diagnostics on mismatch. Resolve package-local fixtures relative to the package directory, such as `testdata/response.json`; surface fixture-read/JSON errors. Keep separate fixtures for distinct authorization outcomes.

### Environment Setup for Tests

Load `.env`, falling back to `env.sample`; fail if neither loads. Override DB host/port to local Compose containers (`localhost`, `23306` in the reference project), never production connections.

### Running Integration Tests

Start via `make up` before testing integration packages; Go race requirements still apply. Prefer `make fulltest` combining startup, readiness, execution and cleanup per [Docker DB testing](docker-db-testing.md).
