---
name: lang-typescript
description: 'TypeScript and Angular coding best practices. Use when working with TypeScript, Angular, or Node.js files: implementation, testing, refactoring, signals, RxJS Observables, type system, strict mode, generics, and async patterns. Not for HTML templates, HTMX, or CSS: use the `lang-html` skill.'
---
# lang-typescript

## Core Principles

- Keep functions pure where possible; isolate side effects at edges. Never mutate inputs or arguments.
- Use `const` unless reassignment is necessary; `readonly` for immutable properties.
- Explicitly type parameters and returns. Replace `any` with a proper type or narrowed `unknown`.
- Prefer `interface` for object shapes; `type` for unions, intersections, mapped types.
- Require an explanatory comment with `@ts-ignore`. Comments otherwise follow `documentation-rules` Code Comments.
- New Angular DI uses field-initializer `inject()`; retain constructor injection consistency in existing files.

## Reference

Load for the changed concern; these files own its rules:

| Concern | Reference |
|---------|-----------|
| Generics, narrowing, utility types, `satisfies` | [types](references/types.md) |
| Typed errors, Result, error streams | [errors](references/errors.md) |
| Promises, signals, RxJS, teardown | [async](references/async.md) |
| Angular/Node layout, compiler settings | [project structure](references/project-structure.md) |

## Agent Behavior

Before adding services/components, run tree-sitter `find_similar_code` for reuse. Before changing a public interface, map it with `get_symbols(symbol_types: ["functions", "classes"])`. Before strict-type enforcement, audit `find_usage: any`. For component subscription changes, audit `find_usage: subscribe` against the lifecycle gate in [async](references/async.md#angular-component-lifecycle).
