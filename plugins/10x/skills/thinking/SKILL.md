---
name: thinking
description: 'Use when writing, reviewing, or refactoring code: surface assumptions, avoid overcomplication, make surgical changes, and verify success. Not for grading code: use built-in /code-review.'
---

# Thinking contracts

Bias toward caution; use judgment for trivial tasks.

## 1. Think Before Coding

- State assumptions and competing interpretations; never choose silently. Offer simpler approaches and challenge suboptimal requests.
- Complete work independent of uncertainties first. If interpretations yield materially different work, name the ambiguity and ask at most 2 questions before output; otherwise state an assumption and proceed.
- Batch independent reads/searches in one message.
- Prove referenced scripts, files, helpers and symbols exist before documenting/testing against them. Missing items are proposals, never facts.

## 2. Simplicity First

- Before adding code, check reuse/improvement with tree-sitter `find_similar_code`.
- Stop at the first sufficient solution source: need to exist at all, existing code, standard library, native platform, installed dependency, new code, new dependency last. Name the cost of skipping; skip if nothing breaks. Consult lang-* for language-specific choices.
- No unrequested features/configurability, single-use abstractions or impossible-scenario error handling. Rewrite 200 lines if 50 suffice.
- Before a new type/interface/config knob/layer, give one sentence proving the simpler form insufficient. If difficult, keep it simple. An abstraction must reduce reader context and remove more concepts than it adds.
- Materialize only as needed: expression, named helper, file, type, package, module/service. Name recurring rules as helpers first; keep concepts contiguous, avoid extraction of obvious lines that adds navigation.
- State deliberate scope ceilings as `skipped: X, add when Y`, with an observable trigger, never “later”. Put this in reply, phase or commit body, not a code comment.
- Implement supplied mockups/specs/interactions as given. Raise alternatives before substituting them.
- Simplify if a senior engineer would call the result overcomplicated.

## 3. Surgical Changes

Every changed line must trace to the request. Match existing style; do not improve adjacent code/comments/formatting or refactor unbroken code. Mention unrelated dead code without deleting it. Remove only imports, variables and functions your changes orphaned, unless broader cleanup was requested.

## 4. Goal-Driven Execution

Define verifiable goals and loop until verified: validation requires invalid-input tests; bugfixes require a reproducer made green; refactors require tests passing before and after.

For multi-step work, state a brief plan:
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```
