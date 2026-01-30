# Integration Testing

## Go: API Integration Tests

Integration tests talk to a real running server (started via Docker Compose). They live in `internal/api/api_test.go` and run after the server is healthy.

### HTTP Request Helper

Build a shared `makeRequest` helper that sets common headers and injects any auth headers your API expects:

```go
func makeRequest(verb, url, payload string, headers map[string]string) (*http.Response, error) {
    transport := http.DefaultTransport.(*http.Transport).Clone()
    transport.TLSClientConfig = &tls.Config{InsecureSkipVerify: true}
    client := &http.Client{Transport: transport}

    req, err := http.NewRequest(verb, "http://localhost:8080"+url, bytes.NewReader([]byte(payload)))
    if err != nil {
        return nil, fmt.Errorf("makeRequest: %w", err)
    }
    req.Header.Set("Content-Type", "application/json")
    for k, v := range headers {
        req.Header.Set(k, v)
    }

    return client.Do(req)
}
```

### JSON Fixture Comparison

Store expected responses as JSON files in `assets/tests/`. Compare actual vs expected with `jsondiff` to get a structured diff on failure.

```go
func TestGetPerson(t *testing.T) {
    resp, err := makeRequest("GET", "/persons-api/v1/persons/100071", "", "service", "M00001", "")
    require.NoError(t, err)
    defer resp.Body.Close()

    body, _ := io.ReadAll(resp.Body)
    assert.Equal(t, 200, resp.StatusCode)

    equal, diff, err := compareWithFixture(string(body), "GET_person_100071.json")
    require.NoError(t, err)
    assert.True(t, equal, "response differs from fixture:\n%s", diff)
}

func compareWithFixture(actual, filename string) (bool, string, error) {
    pwd, _ := os.Getwd()
    root := strings.ReplaceAll(filepath.ToSlash(pwd), "internal/api", "")
    expected, err := os.ReadFile(filepath.Join(root, "assets", "tests", filename))
    if err != nil {
        return false, "", fmt.Errorf("compareWithFixture: %w", err)
    }

    var v1, v2 any
    json.Unmarshal([]byte(actual), &v1)
    json.Unmarshal(expected, &v2)

    if reflect.DeepEqual(v1, v2) {
        return true, "", nil
    }
    diff, _ := jsondiff.CompareJSON([]byte(actual), expected)
    return false, string(diff), nil
}
```

Fixture directory layout:
```
internal/api/api_test.go
assets/tests/
  GET_person_100071.json
  GET_person_100071_privileged.json
  POST_person.json
```

### Environment Setup for Tests

Override DB host/port in test setup to target the Docker Compose containers running locally. Fall back to `env.sample` when `.env` is absent.

```go
func loadTestEnv(t *testing.T) {
    t.Helper()
    pwd, _ := os.Getwd()
    root := strings.ReplaceAll(filepath.ToSlash(pwd), "internal/api", "")

    if err := godotenv.Load(root + ".env"); err != nil {
        if err := godotenv.Load(root + "env.sample"); err != nil {
            t.Fatal("no .env or env.sample found")
        }
    }

    // Point to Docker Compose DB, not production
    os.Setenv("DBHOST", "localhost")
    os.Setenv("DBPORT", "23306")
}
```

### Running Integration Tests

Integration tests require the Docker Compose stack to be running. The convention is:

```bash
# Start stack (blocking, with logs)
make compose_run

# Or detached
make compose_run_d

# Then run integration tests
go test -v ./internal/api
```

Use `make fulltest` to combine stack startup, health checking, and test execution in one command. See `references/docker-db-testing.md` for the `run_tests.sh` pattern.

## Quick Reference

| Pattern | Detail |
|---------|--------|
| Test location | `internal/api/api_test.go` |
| Reference fixtures | `assets/tests/*.json` |
| Diff library | `github.com/wI2L/jsondiff` |
| DB port override | `os.Setenv("DBPORT", "23306")` in test setup |
| Stack startup | `make compose_run_d` before `go test` |
| Auth headers | Pass via `X-Krakend-*` headers in `makeRequest` |
