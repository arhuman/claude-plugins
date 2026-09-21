# Concurrency Patterns

## Context Propagation (Mandatory)

Every repository method, blocking/I/O function and long-running operation accepts `context.Context` first. Propagate it through handler, service and repository for cancellation, deadlines and request values; never ignore cancellation. Defer cancel functions for contexts you create. GORM binding is owned by [errors](errors.md#repository-context-pattern-gorm).

## Goroutine Lifecycle Management

Every goroutine needs a termination strategy: WaitGroup, errgroup or channel signaling. For fire-and-wait, `Add` before launch, `defer Done`, then `Wait`; use errgroup for error propagation and first-error cancellation. Never launch unbounded goroutines over user input.

## Bounded Goroutines with errgroup (preferred)

For bounded batches needing error propagation:

```go
func processAll(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(10)
    for _, item := range items {
        g.Go(func() error { return process(ctx, item) })
    }
    if err := g.Wait(); err != nil {
        return fmt.Errorf("worker: process batch: %w", err)
    }
    return nil
}
```

Import `golang.org/x/sync/errgroup`; choose a domain-appropriate cap. `Go` blocks at capacity; no second semaphore needed. For pre-Go-1.22 loop semantics, capture the loop item explicitly.

## Worker Pool

For reusable workers, create a fixed worker count with a buffered task channel (e.g. `workers*2`), consume tasks until closure, and track workers with a WaitGroup. Stop submissions before closing tasks; shutdown closes once and waits.

## Channel Patterns

### Generator

The producer owns output closure (`defer close(out)`). Make sends cancellation-aware with `select { case out <- value: case <-ctx.Done(): return }`.

### Fan-out / Fan-in

Fan-out distributes one input across a bounded worker count. Fan-in forwards each input to a shared output, waits for all forwarders, then closes output once. Include cancellation in blocked receives as well as sends.

### Pipeline

Chain stages that transform/filter typed values. Each stage owns its output closure and exits on cancellation or upstream closure.

## Select Patterns

### Timeout

Set deadlines at call sites with `context.WithTimeout` and `defer cancel`; do not hardcode `time.After` inside functions already accepting context. On cancellation return wrapped `ctx.Err()`. For result/error channels from a one-shot worker, buffer them so late delivery cannot strand the sender; propagate context into the actual work.

### Graceful Shutdown

Select on work/ticker, explicit shutdown signal and `ctx.Done()`. Stop tickers with defer; close shutdown channels once.

## sync.Map, Atomic, and Singleflight

### sync.Map

Default to `map` plus RWMutex. Consider `sync.Map` for write-once/read-many high-contention access or many goroutines operating on disjoint keys; use `Store`, `Load`, `LoadOrStore`, `Delete`.

### atomic

Use `atomic.Int64` (`Add`, `Load`) for independent single-value counters rather than a lock.

### singleflight

Coalesce same-key inflight calls with `singleflight.Group.Do(key, func() (any, error))`; handle its result/error and use `shared` when relevant.

## sync Primitives

Protect shared mutable state with `Mutex` and deferred unlock. For read-heavy state, `RWMutex.RLock/RUnlock` on reads, `Lock/Unlock` on writes. Use `sync.Once.Do` for thread-safe single initialization.

## Rate Limiting

Use `golang.org/x/time/rate` token buckets: `rate.NewLimiter(rate.Limit(rps), burst)`, then `Wait(ctx)` before work; return a wrapped wait error rather than running after cancellation.

## Semaphore

Outside errgroup, use `semaphore.NewWeighted(cap)` with cancellation-aware `Acquire(ctx, weight)` before launch; release only successfully acquired permits with defer and wait for launched work. Protect collected errors with a mutex and combine them with `errors.Join`, including acquisition failure. A buffered-channel semaphore is an alternative: send to acquire with a ctx select, receive to release.

## Generic Channel Helpers

When repeated typed pipelines justify helpers, use `Merge[T](ctx, channels ...<-chan T) <-chan T` and `Stage[T,U](ctx, in <-chan T, fn func(T) U) <-chan U`; apply the channel lifecycle rules above rather than copying separate untyped implementations.

## Quick Reference

Gate: every launch has a cap where input-driven, an exit path and an owner that waits; blocked channel operations can cancel; shared writes synchronize; all owned channels/tickers/permits are released exactly once.
