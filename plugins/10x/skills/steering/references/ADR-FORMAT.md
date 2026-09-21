# ADR Format: Contract v1

Canonical envelope, even when existing ADRs differ. Owned home: `docs/adr/NNNN-slug.md`; foreign home follows steering's ownership table. Create the directory only for the first ADR.

## Template

```md
---
status: proposed | accepted | deprecated | superseded
date: YYYY-MM-DD
---

# Short title of the decision

## Context
One paragraph is fine.

## Decision
What was decided, and why. One sentence is fine.
```

Fill title, status, date and bodies. Fixed: frontmatter status/date, unnumbered title, Context and Decision headings. Optional only when useful: `## Consequences`, `## Considered options`, exactly named. Never body `Date:`, numbered/ADR-prefixed title or status emoji: id comes from filename, status from frontmatter.

## Numbering

Four-digit filename prefix is the id: `0007-slug.md` = `ADR-0007`. Allocate highest existing filename prefix + 1, first `0001`; never derive from headings/indexes or repeat id in title.

## One file per decision

Exactly one decision per file, never monoliths (`docs/ADR.md`, `IN-FLIGHT.md`, accumulated ADR sections). Index allowed only generated, link-only, never authoritative. Explicitly non-authoritative scratchpad allowed (`INBOX.md` or `.claude/`); once an entry passes the gate, promote to its numbered file and replace scratchpad entry with a link.

## Lifecycle: how an ADR changes over time

Accepted decisions are immutable. Typos, links, meaning-preserving wording and status may change. Changed decision requires:

1. New ADR with `supersedes: NNNN`.
2. Old ADR with `status: superseded`, `superseded_by: NNNN`.
3. Keep the old file forever.

Status is state, supersedes/superseded_by are relationships; never `status: superseded by 0009`. Optional one-line top banner points to replacement; no alternate blockquote/emoji mechanisms.

## Verification

Before finalizing and on context resync, run `references/verify-adr.sh` on the set; clean output is required, wire into CI where possible. Check every ADR:

- `NNNN-slug.md`, no monolith/stray home.
- Valid status enum and YYYY-MM-DD date in frontmatter.
- First heading `# Title`, not starting with number or ADR.
- Decision section present.
- Superseded status has superseded_by targeting an existing file.
- Every supersedes/superseded_by target exists.

## Non-conformant repos

Write canonical new ADRs and warn about divergent existing forms. Never imitate debt or silently reformat it; migration requires a separate explicit user request.

## When to offer an ADR

Require all three: hard to reverse, surprising without context, and genuine alternatives with a real trade-off. Missing any: skip.

### What qualifies

Apply that gate to architectural shape, context integrations, lock-in technology, boundaries/ownership and explicit exclusions, deliberate non-obvious deviations, constraints invisible in code, and non-obvious rejected alternatives. Ordinary reversible library choices do not qualify merely because they are technical.
