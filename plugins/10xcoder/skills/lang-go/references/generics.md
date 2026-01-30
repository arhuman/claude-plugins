# Generics and Type Parameters

## Prefer stdlib (Go 1.21+)

Before writing generic utilities, check `slices` and `maps`:

| stdlib function | replaces |
|----------------|---------|
| `slices.Contains` | custom `Contains[T]` |
| `slices.Index` | custom linear search |
| `slices.Sort` | custom sort wrapper |
| `slices.Compact` | custom dedup |
| `maps.Keys` | custom `Keys[K,V]` |
| `maps.Values` | custom `Values[K,V]` |
| `maps.Clone` | custom copy |

Use the custom implementations below only when the stdlib variants don't fit.

## When to Use Generics

Use generics when:
- Writing type-safe collections (Set, Stack, Queue, Ring)
- Writing utility functions that work over multiple numeric or comparable types (Filter, Map, Reduce)
- Writing reusable data pipeline stages

Prefer plain interfaces when:
- Behavior (methods) varies by type — use an interface
- There is only one concrete type in practice — just use that type
- The function only needs `any` — generics add noise without benefit

## Basic Type Parameters

```go
// Single type parameter
func Max[T cmp.Ordered](a, b T) T {
    if a > b {
        return a
    }
    return b
}

// Multiple type parameters
func Map[T, U any](slice []T, fn func(T) U) []U {
    result := make([]U, len(slice))
    for i, v := range slice {
        result[i] = fn(v)
    }
    return result
}

// Usage — type inference works in most cases
maxInt := Max(10, 20)
maxStr := Max("abc", "xyz")
doubled := Map([]int{1, 2, 3}, func(n int) int { return n * 2 })
```

## Type Constraints

```go
import "cmp" // Go 1.21+ — use cmp.Ordered instead of golang.org/x/exp/constraints

// Use the Number constraint (defined below) for numeric sums
func Sum[T Number](nums []T) T {
    var total T
    for _, n := range nums {
        total += n
    }
    return total
}

// Custom constraint with methods
type Stringer interface {
    String() string
}

func PrintAll[T Stringer](items []T) {
    for _, item := range items {
        fmt.Println(item.String())
    }
}

// Approximate constraint — includes type aliases
type Integer interface {
    ~int | ~int8 | ~int16 | ~int32 | ~int64
}

type UserID int // satisfies Integer via ~int
func Double[T Integer](n T) T { return n * 2 }
```

## Union Constraints

```go
// Simple union
type StringOrBytes interface {
    string | []byte
}

// Numeric union
type Number interface {
    int | int8 | int16 | int32 | int64 |
    uint | uint8 | uint16 | uint32 | uint64 |
    float32 | float64
}

func Abs[T Number](n T) T {
    if n < 0 {
        return -n
    }
    return n
}
```

## Generic Data Structures

### Stack

```go
type Stack[T any] struct {
    items []T
}

func (s *Stack[T]) Push(item T) {
    s.items = append(s.items, item)
}

func (s *Stack[T]) Pop() (T, bool) {
    if len(s.items) == 0 {
        var zero T
        return zero, false
    }
    n := len(s.items) - 1
    item := s.items[n]
    s.items = s.items[:n]
    return item, true
}

func (s *Stack[T]) Peek() (T, bool) {
    if len(s.items) == 0 {
        var zero T
        return zero, false
    }
    return s.items[len(s.items)-1], true
}

func (s *Stack[T]) Len() int { return len(s.items) }
```

### Set

```go
type Set[T comparable] struct {
    items map[T]struct{}
}

func NewSet[T comparable](values ...T) *Set[T] {
    s := &Set[T]{items: make(map[T]struct{})}
    for _, v := range values {
        s.Add(v)
    }
    return s
}

func (s *Set[T]) Add(v T)            { s.items[v] = struct{}{} }
func (s *Set[T]) Remove(v T)         { delete(s.items, v) }
func (s *Set[T]) Contains(v T) bool  { _, ok := s.items[v]; return ok }
func (s *Set[T]) Len() int           { return len(s.items) }
```

## Generic Utilities

```go
// Filter — keep elements matching predicate
func Filter[T any](slice []T, predicate func(T) bool) []T {
    result := make([]T, 0, len(slice))
    for _, v := range slice {
        if predicate(v) {
            result = append(result, v)
        }
    }
    return result
}

// Reduce / Fold
func Reduce[T, U any](slice []T, initial U, fn func(U, T) U) U {
    acc := initial
    for _, v := range slice {
        acc = fn(acc, v)
    }
    return acc
}

// Keys and Values from a map
func Keys[K comparable, V any](m map[K]V) []K {
    keys := make([]K, 0, len(m))
    for k := range m {
        keys = append(keys, k)
    }
    return keys
}

func Values[K comparable, V any](m map[K]V) []V {
    values := make([]V, 0, len(m))
    for _, v := range m {
        values = append(values, v)
    }
    return values
}

// Contains — works for any comparable type
func Contains[T comparable](slice []T, target T) bool {
    for _, v := range slice {
        if v == target {
            return true
        }
    }
    return false
}

// Unique — deduplicate preserving order
func Unique[T comparable](slice []T) []T {
    seen := make(map[T]struct{}, len(slice))
    result := make([]T, 0, len(slice))
    for _, v := range slice {
        if _, exists := seen[v]; !exists {
            seen[v] = struct{}{}
            result = append(result, v)
        }
    }
    return result
}
```

## Type Inference

```go
// Inferred from arguments in most cases
Max(10, 20)          // T = int
Max("a", "b")        // T = string
Filter(nums, isEven) // T = int

// Explicit when inference fails or is ambiguous
result := Map[int, string](nums, strconv.Itoa)
```

## Quick Reference

| Feature | Syntax | Use Case |
|---------|--------|----------|
| Basic generic | `func F[T any]()` | Any type |
| Constraint | `func F[T Constraint]()` | Restricted types |
| Multiple params | `func F[T, U any]()` | Transform input → output type |
| Comparable | `[T comparable]` | Types supporting == and != |
| Ordered | `[T cmp.Ordered]` | Types supporting <, >, <=, >= (Go 1.21+) |
| Union | `T interface{int \| string}` | Either concrete type |
| Approximate | `~int` | Include named types based on int |
| Type inference | `F(x)` | No explicit `[T]` needed |
