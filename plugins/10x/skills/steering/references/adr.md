---
status: proposed
date: YYYY-MM-DD
---

# Short title of the decision

## Context
One paragraph is fine.

## Decision
What was decided, and why. One sentence is fine.

<!--
Fill the frontmatter date, the title, and both sections, then delete this whole
comment block: the committed ADR contains no YYYY-MM-DD and no HTML comment.
ADR Contract v1: one decision per file, docs/adr/NNNN-slug.md.
- Next number: highest existing 4-digit prefix + 1 (first ADR is 0001):
    ls docs/adr 2>/dev/null | grep -oE '^[0-9]{4}' | sort -n | tail -1
  The filename prefix IS the id (ADR-0007 == 0007-slug.md). Do NOT number the
  title (# 4. …, ## ADR 0001:) and do NOT add a "Date:" body line.
- status enum: proposed | accepted | deprecated | superseded
  When a later ADR replaces this one, set `status: superseded` and add
  `superseded_by: NNNN`; the new ADR gets `supersedes: NNNN`. Never delete the
  old file. "superseded" is a state; superseded_by/supersedes is the relation.
- Optional sections, only when they add value, with these exact headings:
  `## Consequences`, `## Considered options`.
- Never append to a monolithic store (docs/ADR.md, IN-FLIGHT.md). Never mirror
  non-conformant existing ADRs: write the canonical form and warn.
- Write one only when the decision is hard to reverse, surprising without
  context, and the result of a real trade-off (see ADR-FORMAT.md).
-->
