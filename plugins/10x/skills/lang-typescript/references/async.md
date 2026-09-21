# TypeScript Async Patterns

## async/await

- Return `Promise<T>` from async functions; check `response.ok` before consuming fetch JSON and report HTTP status on failure.
- Run independent operations with `Promise.all`; use `Promise.allSettled` when independent failures are expected, narrowing fulfilled results before reading values.
- Await promises or explicitly mark intentional fire-and-forget with `void`. Never use `setTimeout` for coordination; use Promises/Observables.

## Signals (Angular)

- Default component/service state to `signal`; derive state with `computed`. Use `input()`/`model()` for component I/O and `toSignal`/`toObservable` at RxJS boundaries (provide an initial value when needed).
- Reserve `effect()` for synchronization with non-Angular code, not derived state. Update object-valued signals with new references.

## RxJS Observables (Angular)

Use RxJS for events and async composition: debounce, cancellation, retries, websockets, polling. For search, compose `debounceTime`, `distinctUntilChanged`, `switchMap`. Choose `switchMap` for cancellation, `mergeMap` for parallel work, `concatMap` for ordering, `exhaustMap` to ignore arrivals while busy. Never nest subscriptions.

When retaining legacy `BehaviorSubject` state, project with `map`, suppress duplicates with `distinctUntilChanged`, and share with `shareReplay(1)`; prefer signals for new state.

## Angular Component Lifecycle

Migrate imperative subscriptions toward declarative composition. Every component subscription must have `takeUntilDestroyed` or `DestroyRef` teardown. Outside injection context, pass an injected DestroyRef explicitly:

```typescript
import { DestroyRef, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

// Component fields and method:
private readonly destroyRef = inject(DestroyRef);
ngOnInit(): void {
  this.userService.users$.pipe(
    takeUntilDestroyed(this.destroyRef),
  ).subscribe((users) => { this.users = users; });
}
```

## Avoiding Common Mistakes

Gate: inspect changed async paths for HTTP failure handling, deliberate promise ownership, flattening-operator semantics and lifecycle teardown before accepting them.
