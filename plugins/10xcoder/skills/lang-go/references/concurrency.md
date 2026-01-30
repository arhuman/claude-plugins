# Concurrency Patterns

## Context Propagation (Mandatory)

ALL repository methods and long-running operations MUST accept `context.Context` as the first parameter.

```go
// Repository pattern
func (r *Repository) FindByID(ctx context.Context, id string) (*Entity, error) {
    result := r.db.WithContext(ctx).Where("id = ?", id).First(&entity)
    return &entity, result.Error
}

// Service pattern
func (s *Service) Process(ctx context.Context, id string) (*Entity, error) {
    return s.repo.FindByID(ctx, id)
}

// Background worker
func (w *Worker) Start() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    w.run(ctx)
}
```

Use context for: cancellation, timeout propagation, request-scoped values.
Pass context through the entire call chain from HTTP handler to repository.

## Goroutine Lifecycle Management

Never create a goroutine without a clear termination strategy.

```go
// sync.WaitGroup for fire-and-wait
func processAll(ctx context.Context, items []Item) {
    var wg sync.WaitGroup
    for _, item := range items {
        wg.Add(1)
        go func(i Item) {
            defer wg.Done()
            process(ctx, i)
        }(item)
    }
    wg.Wait()
}

// golang.org/x/sync/errgroup for error propagation
func processAllWithErrors(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)
    for _, item := range items {
        item := item // capture loop variable
        g.Go(func() error {
            return process(ctx, item)
        })
    }
    return g.Wait()
}
```

## Bounded Goroutines with errgroup (preferred)

Use `errgroup.SetLimit` when processing a batch of work with a known concurrency cap and error propagation:

```go
import "golang.org/x/sync/errgroup"

func processAll(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(10) // hard cap: at most 10 goroutines active

    for _, item := range items {
        item := item
        g.Go(func() error {
            return process(ctx, item)
        })
    }
    return g.Wait()
}
```

`g.Go` blocks until a slot is free when the limit is reached — no separate semaphore needed.

## Worker Pool

Bound concurrency when processing large volumes of work.

```go
type WorkerPool struct {
    workers int
    tasks   chan func()
    wg      sync.WaitGroup
}

func NewWorkerPool(workers int) *WorkerPool {
    wp := &WorkerPool{
        workers: workers,
        tasks:   make(chan func(), workers*2),
    }
    for i := 0; i < workers; i++ {
        wp.wg.Add(1)
        go func() {
            defer wp.wg.Done()
            for task := range wp.tasks {
                task()
            }
        }()
    }
    return wp
}

func (wp *WorkerPool) Submit(task func()) {
    wp.tasks <- task
}

func (wp *WorkerPool) Shutdown() {
    close(wp.tasks)
    wp.wg.Wait()
}
```

## Channel Patterns

### Generator

```go
func generateIDs(ctx context.Context, ids []string) <-chan string {
    out := make(chan string)
    go func() {
        defer close(out)
        for _, id := range ids {
            select {
            case out <- id:
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}
```

### Fan-out / Fan-in

```go
// Fan-out: distribute input to multiple workers
func fanOut(ctx context.Context, in <-chan int, workers int) []<-chan int {
    channels := make([]<-chan int, workers)
    for i := 0; i < workers; i++ {
        channels[i] = processStage(ctx, in)
    }
    return channels
}

// Fan-in: merge multiple channels into one
func fanIn(ctx context.Context, channels ...<-chan int) <-chan int {
    out := make(chan int)
    var wg sync.WaitGroup
    for _, ch := range channels {
        wg.Add(1)
        go func(c <-chan int) {
            defer wg.Done()
            for val := range c {
                select {
                case out <- val:
                case <-ctx.Done():
                    return
                }
            }
        }(ch)
    }
    go func() { wg.Wait(); close(out) }()
    return out
}
```

### Pipeline

```go
func pipeline(ctx context.Context, input <-chan int) <-chan int {
    square := make(chan int)
    go func() {
        defer close(square)
        for n := range input {
            select {
            case square <- n * n:
            case <-ctx.Done():
                return
            }
        }
    }()

    filtered := make(chan int)
    go func() {
        defer close(filtered)
        for n := range square {
            if n%2 == 0 {
                select {
                case filtered <- n:
                case <-ctx.Done():
                    return
                }
            }
        }
    }()
    return filtered
}
```

## Select Patterns

### Timeout

Control timeouts via `context.WithTimeout` at the call site — do not hardcode `time.After` inside functions that already accept a context:

```go
func fetchWithTimeout(ctx context.Context, url string) (string, error) {
    result := make(chan string, 1)
    errCh := make(chan error, 1)

    go func() {
        data, err := fetch(url)
        if err != nil {
            errCh <- err
        } else {
            result <- data
        }
    }()

    select {
    case res := <-result:
        return res, nil
    case err := <-errCh:
        return "", err
    case <-ctx.Done():
        return "", fmt.Errorf("fetchWithTimeout: %w", ctx.Err())
    }
}

// Caller sets the deadline:
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
result, err := fetchWithTimeout(ctx, url)
```

### Graceful Shutdown

```go
type Server struct {
    done chan struct{}
}

func (s *Server) Shutdown() { close(s.done) }

func (s *Server) Run(ctx context.Context) {
    ticker := time.NewTicker(time.Second)
    defer ticker.Stop()
    for {
        select {
        case <-ticker.C:
            s.tick()
        case <-s.done:
            return
        case <-ctx.Done():
            return
        }
    }
}
```

## sync.Map, Atomic, and Singleflight

### sync.Map

Use for concurrent-safe maps with high read/write contention (keys written once, read many times):

```go
var m sync.Map
m.Store("key", value)
v, ok := m.Load("key")
m.LoadOrStore("key", defaultVal)
m.Delete("key")
```

Prefer `map + RWMutex` for general cases; use `sync.Map` only when many goroutines access disjoint key sets.

### atomic

For single-value counters without locking:

```go
import "sync/atomic"

var counter atomic.Int64
counter.Add(1)
n := counter.Load()
```

### singleflight

Deduplicate concurrent requests for the same key:

```go
import "golang.org/x/sync/singleflight"

var g singleflight.Group
result, err, shared := g.Do(cacheKey, func() (any, error) {
    return expensiveFetch(ctx, key)
})
_ = shared // true if result was shared with another caller
```

## sync Primitives

```go
// Mutex — protect shared mutable state
type Counter struct {
    mu    sync.Mutex
    count int
}

func (c *Counter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

// RWMutex — read-heavy workloads
type Cache struct {
    mu    sync.RWMutex
    items map[string]any
}

func (c *Cache) Get(key string) (any, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    v, ok := c.items[key]
    return v, ok
}

func (c *Cache) Set(key string, value any) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.items[key] = value
}

// sync.Once — guaranteed single initialization
type Service struct {
    once   sync.Once
    config *Config
}

func (s *Service) getConfig() *Config {
    s.once.Do(func() { s.config = loadConfig() })
    return s.config
}
```

## Rate Limiting

```go
import "golang.org/x/time/rate"

type RateLimiter struct {
    limiter *rate.Limiter
}

func NewRateLimiter(rps int) *RateLimiter {
    return &RateLimiter{limiter: rate.NewLimiter(rate.Limit(rps), rps)}
}

func (rl *RateLimiter) Do(ctx context.Context, fn func() error) error {
    if err := rl.limiter.Wait(ctx); err != nil {
        return fmt.Errorf("RateLimiter.Do: %w", err)
    }
    return fn()
}
```

## Semaphore

```go
type Semaphore struct{ slots chan struct{} }

func NewSemaphore(n int) *Semaphore {
    return &Semaphore{slots: make(chan struct{}, n)}
}

func (s *Semaphore) Acquire(ctx context.Context) error {
    select {
    case s.slots <- struct{}{}:
        return nil
    case <-ctx.Done():
        return ctx.Err()
    }
}

func (s *Semaphore) Release() { <-s.slots }
```

## Generic Channel Helpers

```go
// Merge multiple typed channels into one
func Merge[T any](ctx context.Context, channels ...<-chan T) <-chan T {
    out := make(chan T)
    var wg sync.WaitGroup
    for _, ch := range channels {
        wg.Add(1)
        go func(c <-chan T) {
            defer wg.Done()
            for v := range c {
                select {
                case out <- v:
                case <-ctx.Done():
                    return
                }
            }
        }(ch)
    }
    go func() { wg.Wait(); close(out) }()
    return out
}

// Type-safe pipeline stage
func Stage[T, U any](ctx context.Context, in <-chan T, fn func(T) U) <-chan U {
    out := make(chan U)
    go func() {
        defer close(out)
        for v := range in {
            select {
            case out <- fn(v):
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}
```

## Quick Reference

| Pattern | Use Case | Key Points |
|---------|----------|------------|
| errgroup.SetLimit | Bounded batch work | Blocks on limit; propagates first error |
|---------|----------|------------|
| context.Context | All I/O and blocking ops | First parameter, always propagate |
| WaitGroup | Wait for goroutines | Add before launch, Done in defer |
| errgroup | Wait + error collection | Cancels all on first error |
| Worker Pool | Bounded concurrency | Reuse goroutines, buffered channel |
| Fan-out/Fan-in | Parallel processing | Distribute work, merge results |
| Pipeline | Stream processing | Chain transformations |
| select + Done | Graceful shutdown | Always handle ctx.Done() |
| Mutex | Shared mutable state | Lock/Unlock with defer |
| RWMutex | Read-heavy state | RLock for reads, Lock for writes |
| sync.Once | Single initialization | Guaranteed thread-safe init |
| Rate Limiter | Throttle requests | Token bucket via x/time/rate |
| Semaphore | Cap concurrent ops | Buffered channel pattern |
| sync.Map | Concurrent map, disjoint keys | Prefer over map+RWMutex for disjoint access |
| atomic.Int64 | Single-value counter | No lock needed |
| singleflight | Deduplicate inflight requests | Coalesce calls for the same key |
| Merge[T] | Fan-in typed channels | Generic, context-aware |
| Stage[T,U] | Typed pipeline transform | Generic, context-aware |
