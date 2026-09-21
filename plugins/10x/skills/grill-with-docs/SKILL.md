---
name: grill-with-docs
description: 'Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise. Use when user wants to stress-test a plan against their project''s language and documented decisions. Not for a pure interrogation that leaves documentation untouched: use grill-me.'
---

<what-to-do>

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. Ask only questions that can change what gets built; a question whose every answer leads to the same plan is decorative, skip it. For each question, provide your recommended answer and the tradeoff it accepts; when the facts already point one way, state the leaning instead of feigning neutrality.

Calibrate depth to the density of the input: a thin plan needs the full tree walk; a dense one usually needs one sharp fork, not a recap of the method from square one.

Ask the questions one at a time, waiting for feedback on each question before continuing.

If a question can be answered by exploring the codebase, explore the codebase instead.

For risk, use a premortem: assume the plan shipped and failed, and ask why.

Done when:

- Remaining gaps are explicit assumptions, not hidden ambiguity: that, not question exhaustion, is the stop signal.
- Every branch of the design tree ends in a decision or an explicit, recorded assumption; none is silently dropped.
- Every term resolved during the session appears in `CONTEXT.md`, and every decision that passed the ADR gate has its file (or a declined offer noted in chat).

</what-to-do>

<supporting-info>

## Domain awareness

During codebase exploration, also look for existing documentation:

### File structure

Single vs multi-context layout (root `CONTEXT.md` vs `CONTEXT-MAP.md`), and the lazy-creation rules for `CONTEXT.md` and `docs/adr/`, are defined in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md) and [ADR-FORMAT.md](./ADR-FORMAT.md); follow those rather than re-deriving the layout. In a multi-context repo, each context carries its own `CONTEXT.md` and `docs/adr/`; the root `docs/adr/` holds system-wide decisions only.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y: which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account': do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible: which is right?"

### Update CONTEXT.md inline

Resolve ownership before the first write when `steering` is available in the
session: run `../steering/references/ownership.sh` and, on a `foreign` verdict, write
the same content to `.claude/project/context.md` instead of a tracked root
`CONTEXT.md`, per `steering`'s ownership table. Absent `steering`, default to
root `CONTEXT.md` (the common case) and say so.

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up: capture them as they happen. Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

`CONTEXT.md` should be totally devoid of implementation details. Do not treat `CONTEXT.md` as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

Done when:

- The resolved term is in `CONTEXT.md` in the CONTEXT-FORMAT.md shape, with an _Avoid_ list where aliases were rejected.
- The written file contains no `{...}` placeholder and no leftover instruction line from the format template.

### Offer ADRs sparingly

Only offer an ADR when the decision passes the three-part gate in [ADR-FORMAT.md](./ADR-FORMAT.md) (hard to reverse, surprising without context, the result of a real trade-off); if any leg is missing, skip it. Use that file's template, numbering, and lifecycle rules.

Done when:

- The new ADR passes the ADR-FORMAT.md Verification checklist (run `verify-adr.sh` from the steering skill when available).
- No `NNNN`, `{...}`, or leftover instruction line remains in the written file.

</supporting-info>
