# TypeScript Type System Patterns

## Generics

```typescript
// Constrain generics to meaningful shapes
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

// Use default type parameters to reduce verbosity
interface Repository<T, ID = string> {
  findById(id: ID): Promise<T | null>;
  save(entity: T): Promise<T>;
}
```

## Utility Types

```typescript
// Partial: all fields optional (useful for update DTOs)
type UpdateUserDto = Partial<User>;

// Pick: select a subset of fields
type UserSummary = Pick<User, 'id' | 'name' | 'email'>;

// Omit: remove specific fields
type CreateUserDto = Omit<User, 'id' | 'createdAt'>;

// Required: make all fields mandatory
type CompleteConfig = Required<Config>;

// Readonly: prevent mutation
type ImmutableUser = Readonly<User>;

// Record: key-value map with typed keys and values
type RolePermissions = Record<Role, Permission[]>;
```

## Type Guards

```typescript
// User-defined type guard
function isApiError(value: unknown): value is ApiError {
  return (
    typeof value === 'object' &&
    value !== null &&
    'code' in value &&
    'message' in value
  );
}

// Discriminated union: prefer this over optional fields
type Result<T> =
  | { success: true; data: T }
  | { success: false; error: string };

function handle<T>(result: Result<T>): T {
  if (!result.success) throw new Error(result.error);
  return result.data;
}
```

## Narrowing

```typescript
// Exhaustive check: TypeScript will error if a case is missed
function assertNever(value: never): never {
  throw new Error(`Unhandled value: ${JSON.stringify(value)}`);
}

type Shape = Circle | Rectangle | Triangle;

function area(shape: Shape): number {
  switch (shape.kind) {
    case 'circle': return Math.PI * shape.radius ** 2;
    case 'rectangle': return shape.width * shape.height;
    case 'triangle': return 0.5 * shape.base * shape.height;
    default: return assertNever(shape);
  }
}
```

## Mapped and Conditional Types

```typescript
// Mapped type: transform every property
type Nullable<T> = { [K in keyof T]: T[K] | null };

// Conditional type: type depends on another
type Unwrap<T> = T extends Promise<infer U> ? U : T;

// Template literal types: precise string constraints
type EventName = `on${Capitalize<string>}`;
```

## satisfies

`satisfies` validates a value against a type without widening it: you keep the narrow inferred type AND the type check.

```typescript
// BAD: annotation widens; config.port is number | string, keys unchecked at use sites
const config: Record<string, number | string> = { port: 8080, host: 'localhost' };

// GOOD: checked against the constraint, but config.port stays number
const config = { port: 8080, host: 'localhost' } satisfies Record<string, number | string>;

// Typical use: exhaustive lookup tables with literal value types preserved
const routes = {
  home: '/',
  users: '/users',
} satisfies Record<string, `/${string}`>;
```

Use `satisfies` instead of a type annotation whenever you want both validation and the most specific inferred type (config objects, route tables, theme maps).
