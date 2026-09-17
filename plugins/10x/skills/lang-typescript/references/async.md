# TypeScript Async Patterns

## async/await

```typescript
// Always type the return value of async functions
async function fetchUser(id: string): Promise<User> {
  const response = await fetch(`/api/users/${id}`);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return response.json() as Promise<User>;
}

// Parallel execution: use Promise.all, not sequential awaits
async function loadDashboard(userId: string): Promise<Dashboard> {
  const [user, posts, notifications] = await Promise.all([
    fetchUser(userId),
    fetchPosts(userId),
    fetchNotifications(userId),
  ]);
  return { user, posts, notifications };
}

// Promise.allSettled when failures are expected and independent
const results = await Promise.allSettled(ids.map(fetchUser));
const users = results
  .filter((r): r is PromiseFulfilledResult<User> => r.status === 'fulfilled')
  .map((r) => r.value);
```

## Signals (Angular)

Signals are the primary state primitive for component and service state in modern Angular. Reach for RxJS only for event streams and async composition (debounce, cancellation, retries).

```typescript
import { Component, signal, computed, input, effect, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';

@Component({ /* standalone by default */ })
export class CartComponent {
  private readonly cartService = inject(CartService);

  // Writable state
  readonly quantity = signal(1);
  // Derived state: recomputed only when dependencies change
  readonly total = computed(() => this.quantity() * this.unitPrice());
  // Signal inputs replace @Input()
  readonly unitPrice = input.required<number>();
  // Bridge an Observable into signal-land at the edge
  readonly user = toSignal(this.cartService.user$, { initialValue: null });

  increment(): void {
    this.quantity.update((q) => q + 1);
  }
}
```

Guidance:
- `signal`/`computed` for state, `input()`/`model()` for component I/O, `toSignal`/`toObservable` at the RxJS boundary.
- Use `effect()` sparingly: for synchronization with non-Angular code, not for derived state (that is `computed`).
- Signals pair with `OnPush`/zoneless change detection; avoid mutating objects inside a signal (use `update` with a new reference).

## RxJS Observables (Angular)

Still the right tool for streams over time: user events to debounce, HTTP cancellation, websockets, polling.

```typescript
import { Observable, Subject, BehaviorSubject } from 'rxjs';
import {
  debounceTime, distinctUntilChanged, switchMap,
  takeUntilDestroyed, shareReplay, map, filter,
} from 'rxjs/operators';

// BehaviorSubject for state
private readonly state$ = new BehaviorSubject<AppState>(initialState);
readonly currentUser$ = this.state$.pipe(
  map((s) => s.currentUser),
  distinctUntilChanged(),
  shareReplay(1),
);

// switchMap for cancellable requests (search, navigation)
// Use mergeMap for parallel, concatMap for ordered, exhaustMap for ignoring new while busy
readonly results$ = this.searchTerm$.pipe(
  debounceTime(300),
  distinctUntilChanged(),
  switchMap((term) => this.api.search(term)),
);
```

## Angular Component Lifecycle

```typescript
import { Component, DestroyRef, inject, OnInit } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

@Component({ ... })
export class UserListComponent implements OnInit {
  private readonly destroyRef = inject(DestroyRef);
  private readonly userService = inject(UserService);

  users: User[] = [];

  ngOnInit(): void {
    // takeUntilDestroyed handles unsubscription automatically
    this.userService.users$.pipe(
      takeUntilDestroyed(this.destroyRef),
    ).subscribe((users) => {
      this.users = users;
    });
  }
}
```

## Avoiding Common Mistakes

```typescript
// BAD: subscribe inside subscribe
this.route.params.subscribe((params) => {
  this.userService.getUser(params['id']).subscribe((user) => { ... });
});

// GOOD: use switchMap
this.route.params.pipe(
  switchMap((params) => this.userService.getUser(params['id'])),
  takeUntilDestroyed(this.destroyRef),
).subscribe((user) => { ... });

// BAD: floating promise (unhandled rejection)
async ngOnInit() {
  loadData(); // missing await
}

// GOOD: handle or void explicitly
async ngOnInit() {
  await loadData();
  // or: void loadData(); // if intentionally fire-and-forget
}
```
