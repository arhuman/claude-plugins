---
name: thinking
description: 'Thinking guidelines to reduce common coding mistakes. Use when writing, reviewing, or refactoring code to avoid overcomplication, make surgical changes, surface assumptions, and define verifiable success criteria. Not for grading or scoring existing code: use the built-in /code-review.'
---

# 10x Thinker

Thinking guidelines to reduce common coding pitfalls.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, first do everything that doesn't depend on the answer. For the rest: if either reading yields materially different work, name what's confusing and ask at most 2 questions before producing output. Otherwise state your assumption and proceed.
- **Batch independent reads.** When the next step needs several files, greps or searches that do not depend on each other's results, issue them in one message so they run in parallel. A thousand one-at-a-time greps is hours of pure model latency: measured on a real project, ~1370 sequential grep/sed calls where a handful of batched reads would have carried the same information.
- **No phantom references.** Before documenting or testing against a script, file, helper or symbol, prove it exists (`ls`, `grep`, tree-sitter). A plausible name is not evidence. If it does not exist, write it as a proposal to add it, never as a statement of fact.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- Always look first if existing code could be reused/improved before adding new one: use tree-sitter `find_similar_code` to detect duplication before writing anything new
- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.
- **Defend the abstraction.** Any new type, interface, config knob or layer costs one sentence first: why the simpler form (two booleans, a helper function, an inline check) is actually insufficient here. If that sentence is hard to write, keep the simple form.
- **Reader's context budget.** Optimize first for the amount of context a reader needs to understand the normal execution path. Introduce an abstraction only when it reduces that amount of context. An abstraction must remove more concepts than it introduces.
- **Materialization ladder.** expression, then named helper, then file, then type, then package, then module/service. Move down a level only when the previous one is insufficient. A new concept deserves a name. It does not automatically deserve a package.
- **Solution-source ladder.** Before writing anything, stop at the first rung that holds: (1) does this need to exist at all? (2) already in the codebase? (3) standard library? (4) native platform feature? (5) a dependency already installed? (6) new code, and a new dependency last of all. Rung 1 is a real question, not rhetoric: name what the task costs if skipped, and skip it when nothing breaks. Language specifics (which stdlib packages to prefer) live in the lang-* skills.
- **Skipped work names its trigger.** A deliberate scope ceiling is stated as "skipped: X, add when Y", with Y a concrete observable condition ("when the list exceeds one page"), never "later". The ceiling goes in the reply, the plan phase, or the commit body, not in a code comment. A skip without a trigger is not a decision, it is a leak.
- **Helpers as vocabulary, kept contiguous.** Name a recurring rule as a function (`user.CanReceiveEmail()`) before reaching for a type, interface, or package; extract only recurring concepts. Do not extract a few obvious lines if the extraction forces the reader to jump elsewhere.
- **Match the spec you were given.** When a mockup, design doc or explicit interaction was provided, implement it as specified. Substituting a different pattern because it seems cleaner is a defect, not a judgment call: raise the alternative, do not ship it silently.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
