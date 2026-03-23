# Error Handling

## Philosophy: Errors Are Values

In Go, errors are values. Handle them explicitly at every level; do not use exceptions or panics for recoverable situations. Good error messages enable fast debugging — include the operation name and contextual data.

## Tier 1 — Wrapping (always)

Wrap errors at every level to preserve the full call chain. Use `fmt.Errorf` with `%w`.

```go
// Pattern: "operationName: %w"
func (r *UserRepository) FindByID(ctx context.Context, id string) (*User, error) {
    var user User
    result := r.db.WithContext(ctx).Where("id = ?", id).First(&user)
    if result.Error != nil {
        return nil, fmt.Errorf("UserRepository.FindByID: %w", result.Error)
    }
    return &user, nil
}

func (s *UserService) GetUser(ctx context.Context, id string) (*User, error) {
    user, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("UserService.GetUser: %w", err)
    }
    return user, nil
}
```

This ensures `errors.Is()` and `errors.As()` work correctly up the entire call chain.

## Tier 2 — Sentinel Errors

Define sentinel errors when callers need to branch on a specific condition.

```go
var (
    ErrNotFound      = errors.New("not found")
    ErrAlreadyExists = errors.New("already exists")
    ErrUnauthorized  = errors.New("unauthorized")
)

func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
    var user User
    result := r.db.WithContext(ctx).Where("email = ?", email).First(&user)
    if errors.Is(result.Error, gorm.ErrRecordNotFound) {
        return nil, fmt.Errorf("FindByEmail %q: %w", email, ErrNotFound)
    }
    if result.Error != nil {
        return nil, fmt.Errorf("FindByEmail: %w", result.Error)
    }
    return &user, nil
}

// Caller can branch cleanly:
user, err := repo.FindByEmail(ctx, email)
if errors.Is(err, ErrNotFound) {
    return nil, ErrUnauthorized // don't leak existence
}
```

Use sentinel errors for stable, well-defined outcomes. Do not create a sentinel for every possible error — only when callers need to identify it programmatically.

## Tier 3 — Custom Error Types

Use structured error types when callers need to extract machine-readable context.

```go
// Custom error type with context
type ValidationError struct {
    Field   string
    Value   any
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed for field %q (value: %v): %s", e.Field, e.Value, e.Message)
}

// Unwrap is only needed when this type holds a wrapped cause.
// Remove this method if ValidationError is a leaf error (no wrapped cause).
func (e *ValidationError) Unwrap() error { return nil }

// Usage
func validateUser(u *User) error {
    if u.Email == "" {
        return &ValidationError{Field: "email", Value: u.Email, Message: "email is required"}
    }
    return nil
}

// Caller extracts structured data
var ve *ValidationError
if errors.As(err, &ve) {
    log.Warn("validation error", zap.String("field", ve.Field))
    return http.StatusBadRequest
}
```

## errors.Join (Go 1.20+)

Combine multiple errors into one — useful for validation that collects all failures before returning:

```go
// errors.Join wraps multiple errors into one
err := errors.Join(err1, err2, err3)

// errors.Is and errors.As traverse all wrapped errors
if errors.Is(err, ErrNotFound) { ... }
```

## errors.Is vs errors.As

```go
// errors.Is — check identity (equality) in the chain
if errors.Is(err, ErrNotFound) { ... }

// errors.As — check type in the chain and extract the value
var ve *ValidationError
if errors.As(err, &ve) {
    fmt.Println("invalid field:", ve.Field)
}

var dbErr *pgconn.PgError
if errors.As(err, &dbErr) && dbErr.Code == "23505" {
    return ErrAlreadyExists
}
```

## Unwrap() Requirement

Any custom error type that wraps another error MUST implement `Unwrap()`:

```go
type ServiceError struct {
    Op  string
    Err error
}

func (e *ServiceError) Error() string {
    return fmt.Sprintf("%s: %v", e.Op, e.Err)
}

func (e *ServiceError) Unwrap() error { return e.Err }
```

This ensures `errors.Is()` and `errors.As()` can traverse the chain.

## Repository Context Pattern (GORM)

All GORM operations must use `WithContext()` to propagate request context:

```go
// Always — enables cancellation and timeout propagation
result := r.db.WithContext(ctx).Create(entity)
result := r.db.WithContext(ctx).Where("id = ?", id).First(&entity)
result := r.db.WithContext(ctx).Save(entity)
result := r.db.WithContext(ctx).Delete(&Entity{}, id)
```

Never call GORM methods without `WithContext(ctx)` in request handlers or service methods.

## Error Message Conventions

```
"OperationName: description"          // wrapping another error
"OperationName: field %q: %w"         // including contextual data
"OperationName: expected X, got Y"    // descriptive without wrapping
```

Examples:
```go
fmt.Errorf("CreateUser: %w", err)
fmt.Errorf("ParseConfig: field %q missing", key)
fmt.Errorf("UpdateBalance: account %s: insufficient funds, have %d need %d", id, have, need)
```

## Anti-Patterns to Avoid

```go
// BAD: silent discard
result, _ := doSomething()

// BAD: panic for recoverable errors
if err != nil {
    panic(err)
}

// BAD: losing the original error
return fmt.Errorf("something went wrong") // no %w — breaks errors.Is/As

// BAD: overly generic messages
return fmt.Errorf("error occurred")

// BAD: returning errors.New in a hot path with formatting
return errors.New("user " + id + " not found") // allocates; use fmt.Errorf

// GOOD
return fmt.Errorf("FindUser %q: %w", id, ErrNotFound)
```

## Logging vs Returning Errors

**Rule**: log OR return, never both at the same level.

```go
// BAD: double-logs the error
func (s *Service) Process(ctx context.Context, id string) error {
    err := s.repo.Find(ctx, id)
    if err != nil {
        s.log.Error("failed to find", zap.Error(err)) // logged here
        return fmt.Errorf("Process: %w", err)         // and surfaced to caller who also logs
    }
    return nil
}

// GOOD: return and let the top-level handler log
func (s *Service) Process(ctx context.Context, id string) error {
    if err := s.repo.Find(ctx, id); err != nil {
        return fmt.Errorf("Process: %w", err)
    }
    return nil
}
```

## Quick Reference

| Scenario | Approach |
|----------|----------|
| Always | `fmt.Errorf("Op: %w", err)` |
| Caller branches on condition | Sentinel: `var ErrX = errors.New(...)` |
| Caller needs structured data | Custom type with `Error()` + `Unwrap()` |
| Check sentinel in chain | `errors.Is(err, ErrX)` |
| Extract typed error | `errors.As(err, &target)` |
| GORM operations | `db.WithContext(ctx).Operation(...)` |
| Log or return | Never both at the same level |
| Panic | Only for unrecoverable programmer errors |
