# Interface Design and Composition

## Core Principle: Accept Interfaces, Return Structs

Default to concrete types. At a genuine behavioral seam, accept the needed interface and return concrete types so callers retain the full API without assertions.

## Small, Focused Interfaces

Prefer one-method interfaces; compose only needed capabilities (`io.Reader`, `io.Writer`, `io.Closer`, `io.ReadCloser`, `io.ReadWriteCloser`).

## Interface Segregation

Split fat interfaces when actual consumers have differing needs. Each consumer declares its narrow interface then composes locally; never pre-split a provider repository into speculative CRUD interfaces.

## Functional Options Pattern

Prefer functional options to large constructor lists; initialize defaults before applying options:

```go
type Option func(*Server)

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}

func NewServer(opts ...Option) *Server {
    s := &Server{host: "localhost", port: 8080, timeout: 30 * time.Second, maxConns: 100}
    for _, opt := range opts {
        opt(s)
    }
    return s
}
```

## Compile-Time Interface Verification

Assert implementations and mocks statically: `var _ io.Reader = (*MyReader)(nil)` or `var _ UserRepository = (*mockUserRepo)(nil)`.

## io.Reader / io.Writer Patterns

Reader decorators transform only `p[:n]` and preserve `(n, err)`; counting writers count bytes actually written. Compose sequential input with `io.MultiReader`, copy while reading with `io.TeeReader`. Bounded-read/truncation rules belong to [memory](memory.md#http-body-lifecycle).

## Embedding for Composition

Embed to promote methods, not simulate inheritance. A map wrapper may embed `sync.RWMutex`; an overridable logger may embed its interface with a default no-op implementation. Follow [concurrency](concurrency.md#sync-primitives) for locking.

## Type Assertions and Type Switches

Use safe two-value assertions (`v, ok := x.(T)`), never a potentially panicking single-value assertion. For several types, use a type switch instead of repeated assertions. Detect optional capabilities such as `Flush() error` after successful `Write`, handling both errors.

## Dependency Injection via Interfaces

Declare interfaces in the consuming package, not the provider. Inject DB/network/filesystem/clock/process dependencies at consumption; [project structure](project-structure.md#composition-root-internalapp) owns process wiring.

## Constructors Normalize Nil Dependencies

`New*` normalizes optional logger, metrics, clock, config or scanner dependencies to safe defaults. Required dependencies such as a DB must produce an error or have a documented hard precondition; never fabricate them. Defaults must be inert, with no surprising I/O: nil logger uses `slog.New(slog.DiscardHandler)` (Go 1.24+), nil config yields zero-value behavior; a scanner may use the default regex scanner. Return the concrete service.

## When NOT to Define an Interface

For a single implementation, require a genuine external dependency inversion. Testability alone is insufficient: concrete structs, an in-memory DB or fixed time can be injected. Mock only process-boundary dependencies. Do not add seams for hypothetical implementations; introduce them with the actual second implementation or dependency.

## Quick Reference

Before `type X interface`, name the caller benefit beyond mocking. Gate: concrete default, consumer ownership, only needed methods, compile-time conformance, and explicit optional/required constructor behavior.
