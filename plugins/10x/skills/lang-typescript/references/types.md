# TypeScript Type System Patterns

## Generics

Constrain parameters to meaningful shapes (`K extends keyof T`, return `T[K]` for property access). Give common parameters defaults, e.g. `Repository<T, ID = string>`.

## Utility Types

Derive rather than duplicate shapes: `Partial` for optional update fields, `Pick` for subsets, `Omit` for excluded generated fields, `Required` for complete config, `Readonly` for immutable views, `Record<K,V>` for typed maps.

## Type Guards

Narrow unknown objects with non-null/object checks and required field checks. Prefer discriminated unions to optional fields for mutually exclusive states; [errors](errors.md#result-pattern) owns Result.

## Narrowing

For exhaustive switches, route the default through a `never` check. Gate: adding a union member must produce a compile error until handled.

```typescript
function assertNever(value: never): never {
  throw new Error(`Unhandled value: ${JSON.stringify(value)}`);
}
```

## Mapped and Conditional Types

Use mapped types for property transformations (`{ [K in keyof T]: T[K] | null }`), conditional types with `infer` for extraction (`T extends Promise<infer U> ? U : T`), and template literal types for constrained strings (`` `on${Capitalize<string>}` ``).

## satisfies

For config, routes, themes and lookup tables needing validation without widening inference, use `satisfies`, not a widening annotation:

```typescript
const config = { port: 8080, host: 'localhost' } satisfies Record<string, number | string>;
```

Gate: the constraint rejects invalid entries while `config.port` remains `number`; finite-key `Record` tables cover every required key.
