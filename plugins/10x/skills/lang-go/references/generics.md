# Generics and Type Parameters

## Prefer stdlib (Go 1.21+)

Before custom utilities, check `slices.Contains`, `Index`, `Sort`, `Compact`, and `maps.Keys`, `Values`, `Clone`. Use custom code only when those semantics do not fit; `Compact` removes adjacent duplicates, not arbitrary repeated values. Iterator-based map helpers are covered in [slog](slog.md#range-over-func-iterators-go-123).

## When to Use Generics

Use generics for type-safe Set/Stack/Queue/Ring collections, utilities across numeric/comparable types, or reusable pipeline stages. Use interfaces for varying method behavior (subject to [interface rules](interfaces.md)); use a concrete type if only one exists, and plain `any` if no type relationship is needed.

## Basic Type Parameters

Use `[T any]` for one type and `[T,U any]` for transformations; allocate a Map result to input length and assign transformed elements by index.

## Type Constraints

Use `cmp.Ordered` (Go 1.21+), not `golang.org/x/exp/constraints`, for ordering. Use `comparable` for equality/map keys, method constraints for required capabilities. `~int` includes named int-based types (e.g. `type UserID int`).

## Union Constraints

Use unions for allowed types (`interface{ string | []byte }`); numeric sums/absolute-value helpers require numeric constraints, not all ordered types:

```go
type Number interface {
    int | int8 | int16 | int32 | int64 |
        uint | uint8 | uint16 | uint32 | uint64 |
        float32 | float64
}
```

Add `~` to union members when named underlying types must be accepted.

## Generic Data Structures

### Stack

Use `[]T`; Push appends, Pop returns/removes the last element, Peek leaves it, Len reports length. Empty Pop/Peek return the zero value and false:

```go
type Stack[T any] struct{ items []T }

func (s *Stack[T]) Push(v T) { s.items = append(s.items, v) }
func (s *Stack[T]) Len() int { return len(s.items) }
func (s *Stack[T]) Peek() (T, bool) {
    if len(s.items) == 0 { var zero T; return zero, false }
    return s.items[len(s.items)-1], true
}
func (s *Stack[T]) Pop() (T, bool) {
    v, ok := s.Peek()
    if ok {
        n := len(s.items)-1
        var zero T
        s.items[n] = zero
        s.items = s.items[:n]
    }
    return v, ok
}
```

### Set

Use `map[T]struct{}` with `T comparable`. Allocate before Add; constructor may insert initial values. Remove uses `delete`, Contains uses two-value lookup, Len uses `len`.

## Generic Utilities

When stdlib cannot satisfy the need: Filter preserves predicate-matching elements; Reduce folds from an explicit initial accumulator; Unique uses a seen map and preserves first-occurrence order. Keys/Values must not promise map iteration order. Contains requires `comparable`; follow [memory](memory.md#pre-allocate-slices-and-maps) for capacity.

## Type Inference

Prefer inferred calls; specify parameters only when inference fails or is ambiguous, e.g. `Map[int,string](nums, strconv.Itoa)`.

## Quick Reference

Gate: demonstrate the stdlib mismatch, choose the narrow required constraint, and verify collection empty-state and ordering semantics.
