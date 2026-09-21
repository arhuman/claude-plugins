# TypeScript Error Handling

## Typed Error Classes

Application errors extend `Error`, carry readonly `code` and `statusCode` (default 500), set `name` to the concrete class, and preserve `instanceof` with `Object.setPrototypeOf(this, new.target.prototype)`. Not-found errors include resource/id, code `NOT_FOUND`, status 404. Validation errors use `VALIDATION_ERROR`, status 400, and readonly `fields: Record<string, string>`.

## Result Pattern

Prefer Result over throwing for expected failures. Narrow on `ok` before accessing either payload:

```typescript
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

function ok<T>(value: T): Result<T, never> {
  return { ok: true, value };
}

function err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}
```

## RxJS Error Handling

In `catchError`, narrow the error: recover a recognized not-found with `of(null)` when absence is allowed; rethrow unknown errors using `throwError(() => error)`. To notify and stop without emitting, notify then return `EMPTY`. Gate: each branch explicitly recovers, propagates, or completes.

## Unknown Error Narrowing

Catch as `unknown`. Use `Error.message` for Error instances, the string itself for strings, otherwise `'An unexpected error occurred'`; log the normalized message.
