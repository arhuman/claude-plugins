# Testing

## Tests as User Contracts

**Tests define the contract between code and its users.**

- Do NOT modify or remove existing test assertions without explicit user approval
- Do NOT remove test cases without user approval — each case encodes a known behavior
- Preserve test intent: you may refactor test structure, helpers, and setup code freely
- When adding new test cases: add them with a `// TODO: uncomment and validate with user` comment and notify the user
- When changing behavior under test: explain your reasoning and ask for confirmation first

## Table-Driven Tests

The standard Go testing pattern — use it for any function with multiple input/output scenarios.

```go
func TestDivide(t *testing.T) {
    tests := []struct {
        name      string
        a, b      float64
        want      float64
        wantErr   bool
    }{
        {"positive", 10, 2, 5, false},
        {"negative dividend", -10, 2, -5, false},
        {"fractional", 7, 2, 3.5, false},
        {"divide by zero", 1, 0, 0, true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := Divide(tt.a, tt.b)
            if (err != nil) != tt.wantErr {
                t.Fatalf("Divide(%v, %v) error = %v, wantErr %v", tt.a, tt.b, err, tt.wantErr)
            }
            if !tt.wantErr && got != tt.want {
                t.Errorf("Divide(%v, %v) = %v, want %v", tt.a, tt.b, got, tt.want)
            }
        })
    }
}
```

## Parallel Subtests

```go
func TestConcurrentSafe(t *testing.T) {
    tests := []struct {
        name  string
        input string
        want  string
    }{
        {"lowercase", "hello", "HELLO"},
        {"mixed", "HeLLo", "HELLO"},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            if got := strings.ToUpper(tt.input); got != tt.want {
                t.Errorf("got %q, want %q", got, tt.want)
            }
        })
    }
}
```

## Test Helpers

Use `t.Helper()` so failures point to the caller, not the helper. Prefer `require.NoError` from testify over custom wrappers.

```go
func setupTestDB(t *testing.T) *gorm.DB {
    t.Helper()
    db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
    if err != nil {
        t.Fatalf("failed to open test DB: %v", err)
    }
    t.Cleanup(func() {
        sqlDB, _ := db.DB()
        sqlDB.Close()
    })
    return db
}
```

## testify Usage

Prefer `require` for fatal assertions and `assert` for non-fatal.

```go
import (
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestUserService(t *testing.T) {
    svc := NewUserService(...)

    user, err := svc.Create(ctx, "alice@example.com")
    require.NoError(t, err)          // stops test on failure
    require.NotNil(t, user)

    assert.Equal(t, "alice@example.com", user.Email)
    assert.NotEmpty(t, user.ID)
}
```

### testify/suite for shared setup

```go
type RepoTestSuite struct {
    suite.Suite
    db   *gorm.DB
    repo *UserRepository
}

func (s *RepoTestSuite) SetupTest() {
    s.db = setupTestDB(s.T())
    s.repo = NewUserRepository(s.db, zap.NewNop())
}

func (s *RepoTestSuite) TestCreate() {
    user, err := s.repo.Create(context.Background(), &User{Email: "x@example.com"})
    s.Require().NoError(err)
    s.Equal("x@example.com", user.Email)
}

func TestRepoSuite(t *testing.T) {
    suite.Run(t, new(RepoTestSuite))
}
```

## Mocking with Interfaces

Manual mocks are preferred for small interfaces; use `mockery` for large ones.

```go
// Interface to mock
type EmailSender interface {
    Send(ctx context.Context, to, subject, body string) error
}

// Manual mock
type mockEmailSender struct {
    sent   []sentEmail
    failOn string
}

type sentEmail struct{ To, Subject, Body string }

func (m *mockEmailSender) Send(_ context.Context, to, subject, body string) error {
    if to == m.failOn {
        return fmt.Errorf("mock: forced failure for %s", to)
    }
    m.sent = append(m.sent, sentEmail{to, subject, body})
    return nil
}

func TestRegister_SendsWelcomeEmail(t *testing.T) {
    mailer := &mockEmailSender{}
    svc := NewUserService(newMockRepo(), mailer, zap.NewNop())

    require.NoError(t, svc.Register(context.Background(), "user@example.com"))
    require.Len(t, mailer.sent, 1)
    assert.Equal(t, "user@example.com", mailer.sent[0].To)
}
```

## Benchmarking

```go
func BenchmarkJSON(b *testing.B) {
    data := generateLargePayload()
    b.ResetTimer() // exclude setup from timing

    for i := 0; i < b.N; i++ {
        _, _ = json.Marshal(data)
    }
}

// With subtests for comparing approaches
func BenchmarkEncoders(b *testing.B) {
    cases := []struct {
        name string
        fn   func(any) ([]byte, error)
    }{
        {"json", json.Marshal},
        {"msgpack", msgpack.Marshal},
    }

    for _, c := range cases {
        b.Run(c.name, func(b *testing.B) {
            data := generateLargePayload()
            b.ResetTimer()
            b.ReportAllocs()
            for i := 0; i < b.N; i++ {
                _, _ = c.fn(data)
            }
        })
    }
}

// Parallel benchmark
func BenchmarkConcurrent(b *testing.B) {
    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            doWork()
        }
    })
}
```

Run benchmarks: `go test -bench=. -benchmem ./...`

## Fuzzing (Go 1.18+)

```go
func FuzzParseQuery(f *testing.F) {
    // Seed corpus
    f.Add("key=value")
    f.Add("a=1&b=2")
    f.Add("")

    f.Fuzz(func(t *testing.T, input string) {
        parsed, err := ParseQuery(input)
        if err != nil {
            return // invalid input is acceptable
        }
        // Properties that must always hold
        re := FormatQuery(parsed)
        reparsed, err := ParseQuery(re)
        if err != nil {
            t.Errorf("re-parse failed on %q: %v", re, err)
        }
        if !reflect.DeepEqual(parsed, reparsed) {
            t.Errorf("round-trip mismatch: %v != %v", parsed, reparsed)
        }
    })
}
```

Run fuzzing: `go test -fuzz=FuzzParseQuery -fuzztime=30s`

## Race Detector

Always run tests with `-race` in CI:

```bash
go test -race ./...
```

To detect races in a specific test:
```bash
go test -race -run TestConcurrentAccess ./internal/cache/...
```

## Coverage

```bash
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out        # HTML report
go tool cover -func=coverage.out        # per-function summary
```

Target: 80%+ coverage for business logic packages. Coverage is a floor, not a goal.

## Golden Files

Use for testing complex rendered output (templates, generated code, formatted reports).

```go
var updateGolden = flag.Bool("update", false, "update golden files")

func TestRenderReport(t *testing.T) {
    data := ReportData{Title: "Q1", Items: []Item{{Name: "a", Value: 10}}}
    got := RenderReport(data)

    golden := filepath.Join("testdata", "report.golden")
    if *updateGolden {
        require.NoError(t, os.WriteFile(golden, []byte(got), 0o644))
    }

    want, err := os.ReadFile(golden)
    require.NoError(t, err)
    assert.Equal(t, string(want), got)
}
```

Update: `go test -run TestRenderReport -update`

## Integration Tests

Use build tags to separate integration tests from unit tests.

```go
//go:build integration

package myapp_test

import "testing"

func TestIntegration_CreateUser(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test")
    }
    // ... test against real DB, services, etc.
}
```

Run: `go test -tags=integration ./...`
Run short (unit only): `go test -short ./...`

## HTTP Handler Testing

Test Gin handlers without a live server using `httptest`:

```go
func TestGetUser(t *testing.T) {
    repo := &mockUserRepo{}
    svc := NewUserService(repo, zap.NewNop())
    router := setupRouter(svc)

    w := httptest.NewRecorder()
    req := httptest.NewRequest(http.MethodGet, "/users/1", nil)
    req.Header.Set("Authorization", "Bearer "+testToken)

    router.ServeHTTP(w, req)

    require.Equal(t, http.StatusOK, w.Code)
    var body map[string]any
    require.NoError(t, json.Unmarshal(w.Body.Bytes(), &body))
}
```

## Environment Variables in Tests

Use `t.Setenv` — automatically restored after the test:

```go
func TestConfig(t *testing.T) {
    t.Setenv("DATABASE_URL", "postgres://test")
    cfg, err := config.Load()
    require.NoError(t, err)
    require.Equal(t, "postgres://test", cfg.Database.URL)
}
```

## Quick Reference

| Command | Description |
|---------|-------------|
| `go test ./...` | Run all tests |
| `go test -v -run TestName` | Run specific test, verbose |
| `go test -race ./...` | Enable race detector |
| `go test -bench=. -benchmem` | Run benchmarks with alloc stats |
| `go test -cover` | Show coverage percentage |
| `go test -coverprofile=c.out` | Generate coverage profile |
| `go test -fuzz=FuzzXxx` | Run fuzzer |
| `go test -short` | Skip long tests |
| `go test -tags=integration` | Include integration tests |
| `go test -count=1` | Disable test caching |
