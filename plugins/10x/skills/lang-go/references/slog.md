# Structured Logging (slog) and Iterators

## slog: the default logger

- Use `log/slog` unless a logging framework already exists. Configure once in the composition root: JSON handler to stderr, config-driven `slog.LevelVar` for runtime changes; inject the logger.
- Use structured fields, never Sprintf messages. Attach stable component fields with `logger.With("component", "store")`; prefer typed `LogAttrs` on hot paths.
- Debug by default; Info for one-time/important startup/config events. In request paths use context variants (`InfoContext`, `LogAttrs`) for trace propagation.
- Scrub secrets, tokens and PII; log safe identifiers rather than whole structs on hot paths.
- Adapt third-party loggers through `slog.Handler`, never a custom logger interface. Error log/return policy is in [errors](errors.md#logging-vs-returning-errors).

## Range-over-func iterators (Go 1.23+)

Use `iter.Seq[V]`/`iter.Seq2[K,V]` instead of giant slices when callers may stop early or data exceeds memory. Producers must stop when `yield` returns false and close owned resources even on early exit. With DB rows, propagate query/scan/iteration errors. Consumers check errors before processing records.

Prefer `slices.Values`, `slices.Collect`, `maps.Keys`, `maps.Values` (Go 1.23 iterator helpers). Gate: early break terminates production and frees resources; logs retain fields/context without sensitive values.
