# Code comments: register reference

Read for comment writing/review. [Code Comments](../SKILL.md#code-comments) owns placement, triggers, contract slots, length caps and register tests; this lookup does not override them.

## Banned vocabulary

Unless already a concrete codebase domain term (such as a `Lifecycle` type), ban:

leverage, utilize, facilitate, orchestrate, robust, seamless, comprehensive, ensure, mechanism, paradigm, concern, orthogonal, lifecycle, semantics, holistic, streamline, underlying, appropriate, proper, handle (as the whole verb).

Ban filler rationale: “handle edge cases”, “maintain consistency”, “improve readability”, “for better performance”, “optimize performance” without a named metric/failure, “as needed”, “if necessary”, “for safety”, “best practice”.

The review `ai-slop-checklist.md` section C intentionally checks only a low-false-positive subset, not this full list.

## Concrete subjects

| Replace | With concrete code subjects |
|---|---|
| system, layer, flow | scheduler, WAL, retry loop |
| mechanism, implementation | mutex, bounded channel |
| data, payload, object | digest, row, decoded header |
| handles errors appropriately | returns ErrNotFound; callers must not retry |

## Glossing unavoidable terms

Gloss a necessary domain term once at its first package use, not every occurrence. Example: “Writes are idempotent (safe to retry after a timeout).”

## Citations

Verify a cited path/reference before writing it. If unverifiable, give the reason without a citation; never invent a plausible incident or ADR number.
