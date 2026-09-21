# ADR Format: Contract v1

ADRs live in `docs/adr/`, one file per decision, named `NNNN-slug.md`.

This is a **contract**, not a suggestion: the body stays minimal, but the
*envelope* (identifier, frontmatter, lifecycle, location) is fixed so ADRs read
the same in every repo and stay consistent as they grow. When existing ADRs in a
repo don't match this contract, **do not imitate them**: write the canonical
form and note the divergence (see *Non-conformant repos* below).

Create the `docs/adr/` directory lazily: only when the first ADR is needed.

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

<!-- Fill every placeholder above (title, status, date, section bodies), then delete this line. -->
```

Short is still the goal: `Context` and `Decision` can each be a single
sentence. What is **fixed** is the shape: frontmatter `status` + `date`, a title
with **no number in it**, and the two headings. `## Consequences` and
`## Considered options` are optional; add them only when they carry genuine
value, and use exactly those heading names when you do.

Do **not** write `Date:` as a body line, do **not** number the title
(`# 4. …`, `## ADR 0001:`), do **not** put status emoji in a bold line: the ID
comes from the filename and the status from frontmatter.

## Numbering

The four-digit, zero-padded filename prefix **is** the ID (`ADR-0007` ⇔
`0007-slug.md`). The title never repeats it. Zero-padding keeps files in
decision order lexicographically.

Compute the next number from the filenames, never from a heading or an index:

```sh
printf '%04d\n' "$(( $(ls docs/adr 2>/dev/null | grep -oE '^[0-9]{4}' | sort -n | tail -1 | sed 's/^0*//')0 / 10 + 1 ))"
# simpler and equivalent:
ls docs/adr 2>/dev/null | grep -oE '^[0-9]{4}' | sort -n | tail -1
```

Take the highest existing prefix and add one; if `docs/adr/` is empty the first
ADR is `0001`.

## One file per decision

Exactly one decision per file. **Never** create or append to a monolithic ADR
store: no `docs/ADR.md`, no `docs/adr/IN-FLIGHT.md`, no `## ADR NNN:` sections
accumulated in one file. Monoliths produce colliding numbering namespaces and
are the primary way ADR sets rot.

- An **index** is allowed but must be *generated*, link-only, never hand-curated
  as the source of truth (e.g. `docs/adr/README.md` listing `NNNN: title`).
- A staging **scratchpad** is allowed *if* explicitly labelled non-authoritative
  (`docs/adr/INBOX.md`, or notes under `.claude/`). It is **not** an ADR store:
  once an entry passes the gate below, promote it to `docs/adr/NNNN-slug.md` and
  replace the inbox line with a link.

## Lifecycle: how an ADR changes over time

An accepted ADR's **decision is immutable**. You may fix typos, links, and
wording that doesn't change meaning, and you may update its `status`. You do
**not** rewrite the decision in place.

When the decision actually changes:

1. Write a **new** ADR with `supersedes: NNNN` in its frontmatter.
2. On the **old** ADR, set `status: superseded` and add `superseded_by: NNNN`.
3. Never delete the old file: the superseded record is the history.

`status: superseded` is a *state*; `superseded_by`/`supersedes` are the
*relationship*. Keep them separate (do not write `status: superseded by 0009`).

Optionally add a one-line banner at the top of a superseded ADR pointing to its
replacement. Use only that mechanism: not blockquotes in one repo and emoji in
another.

## Verification

Before finalizing an ADR, and whenever project context is resynced, verify the
set (`docs/adr/`). An ADR set is conformant when every file:

- matches `NNNN-slug.md` (4-digit prefix): flags monoliths and stray homes;
- has frontmatter with a valid `status` enum and a `YYYY-MM-DD` `date`;
- has a `# Title` first heading that does **not** start with a number or `ADR`;
- has a `## Decision` section;
- if `status: superseded`, carries a `superseded_by:` pointing at an existing file;
- if it declares `supersedes:`/`superseded_by:`, the referenced ADR file exists.

A ready-to-run checker ships with the `steering` skill
(`references/verify-adr.sh`); treat a clean run as part of the definition of
done, and wire it into CI where possible.

## Non-conformant repos

If a repo's existing ADRs conflict with this contract (monoliths, numbered
titles, mixed numbering), the agent must **not** mirror them: that is how drift
entrenches. Write new ADRs in the canonical form and surface the divergence as a
warning. Reformatting the existing debt is a separate, explicit, user-invoked
step, never a silent side effect.

## When to offer an ADR

All three of these must be true:

1. **Hard to reverse**: the cost of changing your mind later is meaningful
2. **Surprising without context**: a future reader will look at the code and wonder "why on earth did they do it this way?"
3. **The result of a real trade-off**: there were genuine alternatives and you picked one for specific reasons

If a decision is easy to reverse, skip it: you'll just reverse it. If it's not surprising, nobody will wonder why. If there was no real alternative, there's nothing to record beyond "we did the obvious thing."

### What qualifies

- **Architectural shape.** "We're using a monorepo." "The write model is event-sourced, the read model is projected into Postgres."
- **Integration patterns between contexts.** "Ordering and Billing communicate via domain events, not synchronous HTTP."
- **Technology choices that carry lock-in.** Database, message bus, auth provider, deployment target. Not every library: just the ones that would take a quarter to swap out.
- **Boundary and scope decisions.** "Customer data is owned by the Customer context; other contexts reference it by ID only." The explicit no-s are as valuable as the yes-s.
- **Deliberate deviations from the obvious path.** "We're using manual SQL instead of an ORM because X." Anything where a reasonable reader would assume the opposite. These stop the next engineer from "fixing" something that was deliberate.
- **Constraints not visible in the code.** "We can't use AWS because of compliance requirements." "Response times must be under 200ms because of the partner API contract."
- **Rejected alternatives when the rejection is non-obvious.** If you considered GraphQL and picked REST for subtle reasons, record it: otherwise someone will suggest GraphQL again in six months.
