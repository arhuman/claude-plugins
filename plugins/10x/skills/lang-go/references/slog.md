# Structured Logging (slog) and Iterators

## slog: the default logger

Use `log/slog` when no logging framework is already in place (SKILL.md Module Preferences).

```go
// Setup once in main: JSON handler, level from config
level := new(slog.LevelVar) // dynamic; level.Set(slog.LevelDebug) to change at runtime
logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: level}))
slog.SetDefault(logger)

// Structured fields, never Sprintf into the message
slog.Info("request handled", "method", r.Method, "path", r.URL.Path, "duration", elapsed)

// Type-safe attrs on hot paths (avoids any-boxing of the key)
slog.LogAttrs(ctx, slog.LevelInfo, "request handled",
    slog.String("method", r.Method), slog.Duration("duration", elapsed))

// Component loggers: attach stable fields once
dbLog := slog.Default().With("component", "store")
```

Rules (align with SKILL.md Quality Standards):
- Debug by default; Info for one-time or important events (startup, config).
- Pass `ctx` variants (`InfoContext`, `LogAttrs`) inside request paths so handlers can pick up trace IDs.
- Never log secrets, tokens, or PII; log identifiers, not whole structs, on hot paths.
- Wrap a third-party logger only behind `slog.Handler`, not a custom interface.

## Range-over-func iterators (Go 1.23+)

The `iter` package defines `Seq[V]` and `Seq2[K, V]`; `for range` accepts them.

```go
// Producer: yield returns false when the consumer breaks
func (s *Store) Records(ctx context.Context) iter.Seq2[Record, error] {
    return func(yield func(Record, error) bool) {
        rows, err := s.db.QueryContext(ctx, query)
        if err != nil { yield(Record{}, err); return }
        defer rows.Close()
        for rows.Next() {
            var r Record
            if !yield(r, rows.Scan(&r.ID, &r.Name)) { return }
        }
    }
}

// Consumer
for rec, err := range store.Records(ctx) {
    if err != nil { return err }
    process(rec)
}
```

Use iterators instead of returning giant slices when the caller may stop early or the data does not fit in memory. Prefer the stdlib helpers: `slices.Values`, `slices.Collect`, `maps.Keys`, `maps.Values` (all iterator-based since Go 1.23).
