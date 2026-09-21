# Code comments: register reference

Lookup tables for the Code Comments section of `SKILL.md`. The decisive rules (the position split, the five triggers, the doc-comment slots, the register tests) stay in `SKILL.md`, because they decide *whether* and *where* a comment is written. This file holds the enumerations you consult *while writing the text*, so it does not need to sit in context during a README or ADR edit.

Read this when writing or reviewing a code comment. Everything here elaborates a rule stated in `SKILL.md`; nothing here overrides it.

## Why compression produces jargon

The two symptoms are one mechanism. Squeezing a causal chain into a single line forces nominalization, because concrete nouns need verbs, verbs need clauses, and clauses need room:

```go
// The cap produces this. Shorter and worse:
// Guard against stale-frame offset drift during recovery.

// The doc comment permits this. Longer and useful:
// lastAppliedOffset is the end of the last fully committed operation.
//
// The file size cannot be used here: it may include bytes from an interrupted
// write. Recovery would then start too late and skip valid events.
```

Every concrete noun in the first version has been abstracted away. This is why the length cap applies to inline comments only: at the doc comment the pressure that creates jargon is removed rather than tightened.

## Inline format, good and bad

```go
// Good: one line, names an identifier, states the risk.
// Prevent a race on handlers: they write conns concurrently.

// Bad: narrates the mechanism the code already shows, at length.
// Add a mutex around the map here so that two goroutines cannot access it at
// the same time, because if one writes while another reads it would cause a
// data race and corrupt the map, so the lock serializes all access.
```

The bad version is not fixed by shortening it. It is fixed by asking what a reader could get wrong, which is the concurrent write, and saying only that.

## The essay in a doc comment

The opposite failure to compression, and the one the uncapped contract invites. Nothing here is false or vague; it is simply too much, aimed at the wrong reader:

```go
// Bad: eight lines, three of them tuning history, written for someone who
// already knows how GOGC and soft memory limits behave.
//
// The ceiling is a backstop on how far GOGC may then let the heap grow, not the
// thing that bounds memory. What bounds memory is bytesInFlight, because a soft
// limit cannot shrink a live heap: set below what a run genuinely holds, it
// stops capping anything and only makes the collector run continuously. The
// previous 128 MiB did exactly that, costing 4x the CPU on a repository of
// large files while still peaking five times over its own ceiling. 256 MiB is
// measured to sit above the live heap that bytesInFlight admits, so it caps
// growth without thrashing.

// Good: what actually limits memory, what breaks if you lower this, where the
// numbers live.
//
// memLimit caps heap growth. It does not cap memory use: bytesInFlight does
// that, and Go cannot free memory a run is still holding. Set below what a run
// holds, this limit stops capping anything and the collector runs nonstop
// instead (measured in docs/adr/0012-memory-limits.md).
```

Three moves fixed it: drop the history (git has it), name the concrete actors (`memLimit`, `bytesInFlight`, the collector) instead of "the ceiling" and "the thing that bounds memory", and point at the ADR instead of restating its measurements. A junior can now act on it: *do not lower this, and here is how to check*.

## Banned vocabulary

Banned in comments unless the codebase already uses the word as its own domain term (a `Lifecycle` type makes "lifecycle" concrete; prose about "the component lifecycle" does not):

leverage, utilize, facilitate, orchestrate, robust, seamless, comprehensive, ensure, mechanism, paradigm, concern, orthogonal, lifecycle, semantics, holistic, streamline, underlying, appropriate, proper, handle (as the whole verb).

Banned as filler rationale, because none of them can be false:

"handle edge cases", "maintain consistency", "improve readability", "for better performance", "optimize performance" with no named metric or failure, "as needed", "if necessary", "for safety", "best practice".

`ai-slop-checklist.md` section C greps a subset of this list during review. The list there is deliberately shorter: it holds only words with a low false-positive rate, since a review finding must survive confirmation.

## Concrete subjects

Name the thing, not its category.

| Instead of | Write |
|---|---|
| the system, the layer, the flow | the scheduler, the WAL, the retry loop |
| the mechanism, the implementation | the mutex, the bounded channel |
| data, the payload, the object | the digest, the row, the decoded header |
| handles errors appropriately | returns ErrNotFound; callers must not retry |

A comment naming no identifier from the code it sits on is nearly always restating the code's shape rather than adding to it.

## Glossing unavoidable terms

Domain terms are fine when they carry weight. Gloss them once, in place, rather than assuming the reader shares the vocabulary:

```go
// Writes are idempotent (safe to retry after a timeout), so the caller
// does not need a dedup key.
```

Gloss the term the first time it appears in a package, not at every use.

## The two tests, worked

Both are stated in `SKILL.md`. Examples of what they reject:

**Portability.** Could this be pasted into 20 unrelated codebases unchanged?

- Fails: `// Initialize the service with the given configuration.` True of most services anywhere.
- Passes: `// Start must run after Configure: the pool size is read once, at Start.`

**Falsifiability.** Could the comment be wrong?

- Fails: `// Handles the user data.` No observation could contradict it.
- Passes: `// Callers must not hold mu here: Flush takes it again.` A reader can check this and find it false.

A comment that fails either test is not improved by rewording. Delete it, or replace it with the constraint it was gesturing at.

## Citations

Never cite an issue, incident, ADR, or commit you have not verified exists (`thinking` states the general rule). Incident-memory comments are the highest-value kind and the easiest to fabricate, because a plausible issue number looks exactly like a real one:

```go
// Checkpoint mode RESTART was removed here: it blocked indefinitely under
// write load in production (see docs/adr/0007-checkpoint-modes.md).
```

That comment is worth more than any other in its file if the ADR exists, and is a liability if it does not. Verify the path before writing the reference, or write the reason without the citation.
