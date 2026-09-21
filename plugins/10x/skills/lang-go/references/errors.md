# Error Handling

## Philosophy: Errors Are Values

Handle every error explicitly; no naked `_` discard without justification. Reserve panic for unrecoverable programmer errors, never recoverable failures.

## Tier 1: Wrapping (always)

At each level, wrap the cause with operation/context using `fmt.Errorf("pkg: operation: %w", err)`, not bare `return err`. Preserve the full inspectable chain.

## Tier 2: Sentinel Errors

Only create sentinels for stable conditions callers branch on. Name them `Err*`, e.g. `var ErrNotFound = errors.New("store: not found")`. Translate `gorm.ErrRecordNotFound` to domain not-found where appropriate; authentication may map not-found to unauthorized to avoid leaking existence.

## Tier 3: Custom Error Types

When callers extract machine-readable context, use a `*Error`-suffixed type with `Error() string`; e.g. `ValidationError{Field, Value, Message}`. Leaf errors need no `Unwrap`.

## errors.Join (Go 1.20+)

Use `errors.Join(errs...)` to collect independent failures, such as validation. Identity/type inspection traverses all joined causes.

## errors.Is vs errors.As

Use `errors.Is(err, sentinel)` for identity and `errors.As(err, &target)` for type/context, never direct equality/type assertions on wrapped errors. For PostgreSQL duplicate keys, extract `*pgconn.PgError` and check code `23505` before translating to already-exists.

## Unwrap() Requirement

Every custom error holding a cause implements `Unwrap()`:

```go
type ServiceError struct {
    Op  string
    Err error
}

func (e *ServiceError) Error() string {
    return fmt.Sprintf("service: %s: %v", e.Op, e.Err)
}

func (e *ServiceError) Unwrap() error { return e.Err }
```

## Repository Context Pattern (GORM)

Use `db.WithContext(ctx)` on every GORM operation (Create, query, Save, Delete), including handlers/services. Context call-chain rules live in [concurrency](concurrency.md#context-propagation-mandatory).

## Error Message Conventions

Prefix with the current lowercase package name; include operation and useful fields, with no trailing punctuation. Examples: `"config: parse: field %q missing"`, `"store: find user %q: %w"`. Apply the same prefix to sentinels. Gates: `errorlint` for `%w`, `revive/error-strings` and staticcheck ST1005 for message shape, `errname` for `Err*`/`*Error` naming.

## Anti-Patterns to Avoid

Reject generic messages that lose operation/cause, discarded errors and formatted hot-path `errors.New("user " + id ...)`; use `fmt.Errorf` with contextual formatting.

## Logging vs Returning Errors

Log OR return the same error at a given level, never both. Return wrapped errors for the top-level handler to log.

## Quick Reference

Gate: trace a failure through callers; its sentinel/type must remain discoverable, context retained, and logging performed once.
