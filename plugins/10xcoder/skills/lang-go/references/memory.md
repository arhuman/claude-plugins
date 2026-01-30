# Memory & Resource Management

## HTTP Body Lifecycle

### Request Body (Handlers)

Always limit, drain, and close `r.Body` in HTTP handlers. Without draining, the underlying TCP connection cannot be reused by the server.

```go
// Apply at the top of every handler that reads a body
func (s *Server) createUser(w http.ResponseWriter, r *http.Request) {
    // Limit before reading — prevents runaway client sending large payloads
    r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1 MB
    defer func() {
        io.Copy(io.Discard, r.Body) // drain remainder
        r.Body.Close()
    }()

    var req CreateUserRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        // http.MaxBytesReader sets a 413 response automatically on overflow;
        // json.Decoder returns *http.MaxBytesError in that case.
        var maxErr *http.MaxBytesError
        if errors.As(err, &maxErr) {
            http.Error(w, "request too large", http.StatusRequestEntityTooLarge)
            return
        }
        http.Error(w, "invalid JSON", http.StatusBadRequest)
        return
    }
    // ...
}
```

Use `io.LimitReader` instead of `http.MaxBytesReader` when working outside an HTTP handler (e.g., reading from a file or arbitrary `io.Reader`):

```go
limited := io.LimitReader(r, maxBytes)
data, err := io.ReadAll(limited)
```

### Response Body (HTTP Client)

Never discard `resp.Body` without both draining and closing it. Failing to drain prevents the transport from reusing the connection.

Always limit the body read — a misbehaving or compromised upstream can push unbounded data and cause OOM. Use `io.LimitedReader` (not `io.LimitReader`) when you need to detect truncation rather than silently accept it.

```go
const maxBody = 1 * 1024 * 1024 // 1 MB — tune to domain expectations

var myClient = &http.Client{Timeout: 10 * time.Second} // never use http.DefaultClient

func fetch(url string) ([]byte, error) {
    resp, err := myClient.Get(url)
    if err != nil {
        if resp != nil {
            resp.Body.Close() // client.Do can return non-nil resp on error (e.g. redirects)
        }
        return nil, fmt.Errorf("fetch: %w", err)
    }
    defer func() {
        io.Copy(io.Discard, resp.Body) // drain remainder so transport reuses connection
        resp.Body.Close()
    }()

    limited := &io.LimitedReader{R: resp.Body, N: maxBody + 1}
    data, err := io.ReadAll(limited)
    if err != nil {
        return nil, fmt.Errorf("fetch read: %w", err)
    }
    if limited.N == 0 {
        // N reaches 0 when limit+1 bytes were consumed — stream was truncated
        return nil, fmt.Errorf("fetch: response exceeded %d byte limit", maxBody)
    }
    return data, nil
}
```

**Why `io.LimitedReader` over `io.LimitReader`**: `io.LimitReader` silently truncates — the caller cannot distinguish a legitimate 1 MB response from a silently cut-off 100 MB one. Using `&io.LimitedReader{N: limit+1}` and checking `limited.N == 0` after reading makes overflow explicit and returnable as an error.

---

## Goroutine Count Control

### errgroup with limit (preferred)

`errgroup.SetLimit` is the cleanest way to cap goroutines for a batch of work. Requires `golang.org/x/sync/errgroup`.

```go
import "golang.org/x/sync/errgroup"

func processAll(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(10) // at most 10 goroutines active at once

    for _, item := range items {
        item := item
        g.Go(func() error {
            return process(ctx, item)
        })
    }
    return g.Wait()
}
```

### Weighted semaphore (for non-errgroup scenarios)

```go
import "golang.org/x/sync/semaphore"

const maxConcurrent = 10

func processAll(ctx context.Context, items []Item) error {
    sem := semaphore.NewWeighted(maxConcurrent)
    var wg sync.WaitGroup
    var mu sync.Mutex
    var errs []error

    for _, item := range items {
        if err := sem.Acquire(ctx, 1); err != nil {
            break // context cancelled
        }
        item := item
        wg.Add(1)
        go func() {
            defer sem.Release(1)
            defer wg.Done()
            if err := process(ctx, item); err != nil {
                mu.Lock()
                errs = append(errs, err)
                mu.Unlock()
            }
        }()
    }
    wg.Wait()
    return errors.Join(errs...)
}
```

---

## Heap Escape Reduction

The compiler's escape analysis decides whether a variable lives on the stack or the heap. Heap allocations pressure the GC; minimize them on hot paths.

**Check escape decisions:**
```bash
go build -gcflags="-m=1" ./...
```

### Avoid interface boxing on hot paths

Every value stored in an `interface{}` / `any` escapes to the heap. Prefer concrete types in performance-sensitive code.

```go
// BAD — boxes `n` on every call
func logValue(v any) { fmt.Println(v) }
logValue(42)

// GOOD — no allocation
func logInt(n int) { fmt.Println(n) }
logInt(42)
```

### Return values, not pointers, for small structs

Returning a pointer forces the value to escape. Return by value when the struct is small (≤ a few cache lines); the compiler can inline and stack-allocate it.

```go
// BAD — Point escapes to heap
func newPoint(x, y int) *Point { return &Point{x, y} }

// GOOD — stays on stack at call site
func newPoint(x, y int) Point { return Point{x, y} }
```

Exception: large structs (>= ~128 bytes) or structs whose lifetime exceeds the calling function's frame — use a pointer there.

### Pre-allocate slices and maps

Append growth causes repeated allocations. When the final size is known or estimable, provide capacity upfront.

```go
// BAD
results := []string{}
for _, item := range items {
    results = append(results, transform(item))
}

// GOOD
results := make([]string, 0, len(items))
for _, item := range items {
    results = append(results, transform(item))
}
```

Same for maps:
```go
m := make(map[string]int, expectedSize)
```

### strings.Builder over fmt.Sprintf for repeated concatenation

```go
// BAD — each Sprintf allocates
var s string
for _, part := range parts {
    s += fmt.Sprintf("%s,", part)
}

// GOOD
var b strings.Builder
b.Grow(estimatedLen) // optional but helpful
for _, part := range parts {
    b.WriteString(part)
    b.WriteByte(',')
}
result := b.String()
```

---

## sync.Pool — Reuse Temporary Allocations

Use `sync.Pool` for objects that are frequently allocated, used briefly, and discarded — e.g., `bytes.Buffer`, scratch byte slices, encoder/decoder instances.

```go
var bufPool = sync.Pool{
    New: func() any { return new(bytes.Buffer) },
}

func encode(v any) ([]byte, error) {
    buf := bufPool.Get().(*bytes.Buffer)
    buf.Reset()
    defer bufPool.Put(buf)

    if err := json.NewEncoder(buf).Encode(v); err != nil {
        return nil, fmt.Errorf("encode: %w", err)
    }
    // Copy out before returning buf to pool
    out := make([]byte, buf.Len())
    copy(out, buf.Bytes())
    return out, nil
}
```

**Rules for sync.Pool:**
- Always `Reset()` the object before putting it back
- Never store pointers to pooled objects outside the pool's scope — the GC may reclaim pool contents between GC cycles
- Do not pool objects that hold open resources (file handles, connections)

---

## Quick Reference

| Pattern | Rule |
|---------|------|
| `r.Body` in handlers | `http.MaxBytesReader` + drain + close |
| `resp.Body` in clients — limit | `&io.LimitedReader{R: resp.Body, N: limit+1}` then check `limited.N == 0` for overflow |
| `resp.Body` in clients — drain | `io.Copy(io.Discard, resp.Body)` then close (enables connection reuse) |
| `resp.Body` on `client.Do` error | `if resp != nil { resp.Body.Close() }` before returning the error |
| HTTP client timeout | Never `http.Get`/`http.DefaultClient` — always `&http.Client{Timeout: N}` |
| `io.LimitReader` | use only when silent truncation is acceptable; prefer `io.LimitedReader` otherwise |
| Regex in hot paths | `var re = regexp.MustCompile(...)` at package level — never inside per-request functions |
| Goroutine cap | `errgroup.SetLimit(n)` or `semaphore.NewWeighted(n)` |
| Small structs | return by value, not pointer |
| Hot-path values | avoid storing in `any` / `interface{}` |
| Known-size collections | `make([]T, 0, n)` / `make(map[K]V, n)` |
| String building | `strings.Builder` + `Grow` |
| Temporary buffers | `sync.Pool` with `Reset()` before reuse |
| Escape analysis | `go build -gcflags="-m=1" ./...` |
