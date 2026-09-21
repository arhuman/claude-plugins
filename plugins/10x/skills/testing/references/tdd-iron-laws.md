# TDD Iron Laws

Apply for test-first development, not as a claim that tests written afterward were TDD.

## The Fundamental Principle

No production code without a failing test first. If implementation preceded its test, delete it and start over, no exceptions for simplicity, hurry, manual checks, prior experience or sunk cost.

## The Three Iron Laws

Every production line exists to pass a test written first, observed failing with a meaningful message, then passing because of that code. An unobserved failure proves nothing; later test coverage does not retroactively make work TDD.

## The RED-GREEN-REFACTOR Cycle

1. RED: one minimal behavior test, clear failure, run and observe meaningful red before implementation. For bugs, reproduce the bug; for features, start with simplest behavior.
2. GREEN: simplest code passing that test; no extra features or optimization.
3. REFACTOR: remove duplication/improve clarity while all tests remain green; no new functionality. Add the next failing test before expanding behavior.

## Verification Checklist

Before claiming completion, verify every production function has behavior tests, each written and observed failing before its implementation, all now passing, and refactoring kept the suite green. No untested production code.

Adapted from [obra/superpowers](https://github.com/obra/superpowers), Jesse Vincent (@obra), MIT License.
