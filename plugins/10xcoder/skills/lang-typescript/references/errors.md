# TypeScript Error Handling

## Typed Error Classes

```typescript
// Base application error
export class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number = 500,
  ) {
    super(message);
    this.name = this.constructor.name;
    // Fix prototype chain for instanceof checks
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id: string) {
    super(`${resource} with id ${id} not found`, 'NOT_FOUND', 404);
  }
}

export class ValidationError extends AppError {
  constructor(
    message: string,
    public readonly fields: Record<string, string>,
  ) {
    super(message, 'VALIDATION_ERROR', 400);
  }
}
```

## Result Pattern

Prefer over throwing for expected failures:

```typescript
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

function ok<T>(value: T): Result<T> {
  return { ok: true, value };
}

function err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}

// Usage
async function findUser(id: string): Promise<Result<User, NotFoundError>> {
  const user = await db.users.findById(id);
  if (!user) return err(new NotFoundError('User', id));
  return ok(user);
}

const result = await findUser('123');
if (!result.ok) {
  // result.error is NotFoundError here
  console.error(result.error.code);
  return;
}
// result.value is User here
```

## RxJS Error Handling

```typescript
import { catchError, EMPTY, of, throwError } from 'rxjs';

// Handle and recover
this.userService.getUser(id).pipe(
  catchError((err: unknown) => {
    if (err instanceof NotFoundError) {
      return of(null); // recover with null
    }
    return throwError(() => err); // re-throw unknown errors
  }),
);

// Handle and stop stream
this.userService.getUser(id).pipe(
  catchError((err) => {
    this.notifyError(err);
    return EMPTY; // complete without emitting
  }),
);
```

## Unknown Error Narrowing

```typescript
// Never use catch (e: any) — always narrow from unknown
function toMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;
  return 'An unexpected error occurred';
}

try {
  await riskyOperation();
} catch (error: unknown) {
  logger.error(toMessage(error));
}
```
