# Memory & Resource Management

## HTTP Body Lifecycle

### Request Body (Handlers)

Before reading, wrap `r.Body` with `http.MaxBytesReader(w, r.Body, limit)`; defer draining to `io.Discard` then closing. On decode failure, use `errors.As` for `*http.MaxBytesError` and explicitly send 413; other invalid JSON returns 400. Gin binding does not impose this limit: apply middleware or per-handler limits, including uploads.

Outside HTTP handlers, `io.LimitReader(r, maxBytes)` is acceptable only when silent truncation is acceptable; otherwise use the overflow-detecting pattern below.

### Response Body (HTTP Client)

Use a dedicated `*http.Client` with explicit Timeout, never production `http.Get`, `http.Post` or `http.DefaultClient`. Always limit, drain and close response bodies; on `client.Do` failure close a non-nil response before returning. Never bare `io.ReadAll(resp.Body)`.

```go
func fetch(ctx context.Context, client *http.Client, url string, limit int64) ([]byte, error) {
    req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil { return nil, fmt.Errorf("fetch: request: %w", err) }
    resp, err := client.Do(req)
    if err != nil {
        if resp != nil { resp.Body.Close() }
        return nil, fmt.Errorf("fetch: send: %w", err)
    }
    defer func() {
        io.Copy(io.Discard, resp.Body)
        resp.Body.Close()
    }()
    limited := &io.LimitedReader{R: resp.Body, N: limit + 1}
    data, err := io.ReadAll(limited)
    if err != nil { return nil, fmt.Errorf("fetch: read: %w", err) }
    if limited.N == 0 {
        return nil, fmt.Errorf("fetch: response exceeded %d byte limit", limit)
    }
    return data, nil
}
```

Choose the limit from domain expectations (e.g. 1 MiB). Cleanup drain/close is best-effort after the primary operation. Reading `limit+1` and checking `N == 0` must reject overflow, not accept truncated content.

## Goroutine Count Control

### errgroup with limit (preferred)

Load [bounded errgroup](concurrency.md#bounded-goroutines-with-errgroup-preferred) for batches.

### Weighted semaphore (for non-errgroup scenarios)

Load [semaphore](concurrency.md#semaphore) for acquisition, release, cancellation and error collection; it owns the alternative cap.

## Heap Escape Reduction

Use `go build -gcflags="-m=1" ./...` to inspect compiler escape decisions. Optimize only against measured hot paths; profiling policy is in [lang-go](../SKILL.md#architecture-principles).

### Avoid interface boxing on hot paths

Prefer concrete values; do not box value types into `any` on hot paths without profiling justification. Boxing may allocate; verify rather than assuming every interface value escapes.

### Return values, not pointers, for small structs

Prefer values for structs within a few cache lines. Exception: large structs (roughly >=128 bytes) or lifetimes extending beyond the caller's frame may need pointers; verify escape behavior.

### Pre-allocate slices and maps

For known/estimable sizes, use `make([]T, 0, n)` or `make(map[K]V, n)`.

### strings.Builder over fmt.Sprintf for repeated concatenation

In string-building loops use `strings.Builder`, optionally `Grow(estimatedLen)`, then `WriteString`/`WriteByte` and `String()`, not `fmt.Sprintf` concatenation. Compile hot-path regex once at package scope (`var re = regexp.MustCompile(...)`), never per request.

## sync.Pool: Reuse Temporary Allocations

Pool frequently allocated, short-lived scratch buffers/encoders, never open files/connections. Reset before reuse and before Put; copy output before returning pooled storage. No retained pointer outside the checkout scope; GC may discard pool entries.

```go
var bufPool = sync.Pool{New: func() any { return new(bytes.Buffer) }}

func encode(v any) ([]byte, error) {
    buf, ok := bufPool.Get().(*bytes.Buffer)
    if !ok { return nil, fmt.Errorf("encode: invalid buffer pool entry") }
    buf.Reset()
    defer func() { buf.Reset(); bufPool.Put(buf) }()
    if err := json.NewEncoder(buf).Encode(v); err != nil {
        return nil, fmt.Errorf("encode: json: %w", err)
    }
    return bytes.Clone(buf.Bytes()), nil
}
```

## Quick Reference

Gate: inspect success/error body cleanup, explicit overflow detection, measured allocation changes and absence of aliases to returned pooled memory.
