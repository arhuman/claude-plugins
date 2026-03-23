# Interface Design and Composition

## Core Principle: Accept Interfaces, Return Structs

Functions should accept interfaces (enabling flexibility and testability) and return concrete types (making the API clear to callers).

```go
// Good: accepts io.Reader, returns *ProcessedData (concrete)
func Parse(r io.Reader) (*ProcessedData, error) { ... }

// Bad: returning an interface forces callers to type-assert
func Parse(r io.Reader) (Processor, error) { ... }
```

## Small, Focused Interfaces

Go interfaces work best when they are small — ideally one method.

```go
// Single-method interfaces (idiomatic Go)
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

type Closer interface {
    Close() error
}

// Compose only what you need
type ReadCloser interface {
    Reader
    Closer
}

type ReadWriteCloser interface {
    Reader
    Writer
    Closer
}
```

## Interface Segregation

Split fat interfaces into focused ones; compose at the call site.

```go
// Bad: fat repository interface forces full implementation for every consumer
type Repository interface {
    Create(item Item) error
    Read(id string) (Item, error)
    Update(item Item) error
    Delete(id string) error
    List() ([]Item, error)
    Search(query string) ([]Item, error)
    Count() (int, error)
}

// Good: segregated — each consumer declares only what it needs
type ItemCreator interface { Create(item Item) error }
type ItemReader  interface { Read(id string) (Item, error) }
type ItemUpdater interface { Update(item Item) error }
type ItemDeleter interface { Delete(id string) error }
type ItemLister  interface { List() ([]Item, error) }

// Compose for services that need multiple operations
type ItemRepository interface {
    ItemCreator
    ItemReader
    ItemUpdater
    ItemDeleter
}
```

## Functional Options Pattern

Preferred over large constructor argument lists.

```go
type Server struct {
    host     string
    port     int
    timeout  time.Duration
    maxConns int
    logger   *zap.Logger
}

type Option func(*Server)

func WithHost(host string) Option {
    return func(s *Server) { s.host = host }
}

func WithPort(port int) Option {
    return func(s *Server) { s.port = port }
}

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}

func NewServer(opts ...Option) *Server {
    s := &Server{ // defaults
        host:     "localhost",
        port:     8080,
        timeout:  30 * time.Second,
        maxConns: 100,
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}

// Usage:
// srv := NewServer(WithPort(9000), WithTimeout(60*time.Second))
```

## Compile-Time Interface Verification

Catch missing method implementations at compile time, not at runtime.

```go
// Asserts that *MyReader satisfies io.Reader at compile time
var _ io.Reader = (*MyReader)(nil)
var _ io.Writer = (*MyWriter)(nil)

// Useful for interface verification in tests
var _ UserRepository = (*mockUserRepo)(nil)
```

## io.Reader / io.Writer Patterns

```go
// Custom Reader
type UppercaseReader struct{ src io.Reader }

func (u *UppercaseReader) Read(p []byte) (n int, err error) {
    n, err = u.src.Read(p)
    for i := range p[:n] {
        if p[i] >= 'a' && p[i] <= 'z' {
            p[i] -= 32
        }
    }
    return n, err
}

// Custom Writer (e.g., counting bytes written)
type CountingWriter struct {
    w     io.Writer
    count int64
}

func (cw *CountingWriter) Write(p []byte) (n int, err error) {
    n, err = cw.w.Write(p)
    cw.count += int64(n)
    return n, err
}

func (cw *CountingWriter) BytesWritten() int64 { return cw.count }

// Composing standard library helpers
combined := io.MultiReader(r1, r2)        // reads r1 then r2
tee := io.TeeReader(r, w)                 // reads r, copies to w
limited := io.LimitReader(r, maxBytes)    // cap how much is read
```

## Embedding for Composition

```go
// Embed a struct to inherit its methods
type SafeMap struct {
    sync.RWMutex
    m map[string]string
}

func (s *SafeMap) Get(key string) (string, bool) {
    s.RLock()
    defer s.RUnlock()
    v, ok := s.m[key]
    return v, ok
}

// Embed an interface to provide a default no-op implementation
type Logger interface{ Log(msg string) }
type NoOpLogger struct{}
func (NoOpLogger) Log(_ string) {}

type Service struct {
    Logger // callers can override; default is NoOpLogger
}

func NewService(logger Logger) *Service {
    if logger == nil {
        logger = NoOpLogger{}
    }
    return &Service{Logger: logger}
}
```

## Type Assertions and Type Switches

```go
// Safe two-value assertion — prefer over panicking single-value form
if str, ok := v.(string); ok {
    fmt.Println("string:", str)
}

// Type switch for multiple types
func describe(v any) string {
    switch val := v.(type) {
    case int:
        return fmt.Sprintf("int(%d)", val)
    case string:
        return fmt.Sprintf("string(%q)", val)
    case bool:
        return fmt.Sprintf("bool(%v)", val)
    default:
        return fmt.Sprintf("unknown(%T)", val)
    }
}

// Check for optional interface capability
type Flusher interface{ Flush() error }

func writeAndFlush(w io.Writer, data []byte) error {
    if _, err := w.Write(data); err != nil {
        return fmt.Errorf("writeAndFlush: write: %w", err)
    }
    if flusher, ok := w.(Flusher); ok {
        if err := flusher.Flush(); err != nil {
            return fmt.Errorf("writeAndFlush: flush: %w", err)
        }
    }
    return nil
}
```

## Dependency Injection via Interfaces

**Convention:** Define interfaces in the **consuming** package, not the providing package. This avoids circular imports and keeps abstractions close to where they are used.

```go
// Good: service package defines only what it needs
// package service
type UserRepository interface {
    Get(ctx context.Context, id string) (*User, error)
}

// Bad: repository package defines its own interface and service imports it
```

```go
// Define interfaces for dependencies (in the consuming package)
type UserRepository interface {
    Get(ctx context.Context, id string) (*User, error)
    Save(ctx context.Context, user *User) error
}

type EmailSender interface {
    Send(ctx context.Context, to, subject, body string) error
}

// Service receives interfaces — easy to test with mocks
type UserService struct {
    repo   UserRepository
    mailer EmailSender
    log    *zap.Logger
}

func NewUserService(repo UserRepository, mailer EmailSender, log *zap.Logger) *UserService {
    return &UserService{repo: repo, mailer: mailer, log: log}
}

func (s *UserService) Register(ctx context.Context, email string) error {
    user := &User{Email: email}
    if err := s.repo.Save(ctx, user); err != nil {
        return fmt.Errorf("Register: save: %w", err)
    }
    return s.mailer.Send(ctx, email, "Welcome", "Thanks for registering!")
}
```

## Quick Reference

| Pattern | Use Case | Key Principle |
|---------|----------|---------------|
| Small interfaces | Flexibility | Single-method preferred |
| Accept interfaces | Testability | Depend on abstractions |
| Return structs | Clarity | Don't force type assertions on callers |
| Interface segregation | Loose coupling | No fat interfaces |
| Functional options | Configuration | Flexible, readable constructors |
| Compile-time check | Safety | `var _ Iface = (*T)(nil)` |
| io.Reader/Writer | I/O pipelines | Compose with standard library |
| Embedding | Composition | Promote methods without inheritance |
| Type assertions | Runtime checks | Always use two-value form |
| DI via interfaces | Testing | Mock at interface boundary |
