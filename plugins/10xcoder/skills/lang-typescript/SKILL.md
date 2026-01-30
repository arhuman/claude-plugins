---
name: lang-typescript
description: TypeScript and Angular coding best practices. Use when working with TypeScript, Angular, or Node.js files: implementation, testing, refactoring, RxJS Observables, type system, strict mode, generics, and async patterns.
---
# lang-typescript

## Core Principles

- Prefer explicit types over `any`. If you need `any`, use `unknown` and narrow it.
- Favor `interface` for object shapes, `type` for unions, intersections, and mapped types.
- Keep functions pure where possible. Isolate side effects at the edges.
- Angular: keep components thin. Business logic belongs in services, not templates or components.

## Reference

| Resource | When to use |
|----------|-------------|
| `./references/types.md` | Type system patterns: generics, utility types, type guards, narrowing |
| `./references/errors.md` | Error handling: typed errors, Result pattern, RxJS error streams |
| `./references/async.md` | Async patterns: Promises, async/await, RxJS Observables |
| `./references/project-structure.md` | Angular and Node project layouts |

## MUST DO

- Enable `strict: true` in `tsconfig.json`
- Type all function parameters and return values explicitly
- Use `readonly` on properties that should not be mutated
- Unsubscribe from Observables in Angular components (use `takeUntilDestroyed` or `DestroyRef`)
- Inject dependencies via constructor in Angular services, not `inject()` at module level
- Use `const` by default; `let` only when reassignment is necessary

## MUST NOT

- Use `any` — use `unknown` and narrow, or define a proper type
- Subscribe inside a subscribe (use `switchMap`, `mergeMap`, etc.)
- Mutate objects passed as inputs or function arguments
- Use `@ts-ignore` without a comment explaining why
- Use `setTimeout` for async coordination — use Promises or Observables instead
