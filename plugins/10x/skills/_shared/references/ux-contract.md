# UX contract format (v1)

The authoritative shape of `docs/ux.md`. Consumed by `steering` (which writes
and audits it) and `design-system` (which requires a screen table and a
component registry without ever saying where they live).

## Why the file exists

`design-system` defends the CSS layer with machinery: twelve audits, a
token contract, numeric ratchets. A feature physically cannot introduce a new
colour or spacing rhythm without touching `tokens.css`.

The intent layer has none of that. The skill calls a per-project screen table a
"required artifact" and locates it in "the project design-system skill or
CLAUDE.md"; it requires a new UI concept to be "declared in its registry or
glossary in the same PR as its first use" without that registry existing. So
`audit-breakpoints` fails a build over a stray `768px`, while a screen can ship
with no recorded purpose at all.

This file is that registry. Where `CONTEXT.md` fixes the language of the domain,
`docs/ux.md` fixes the language of the interface.

## Location and tracking

`docs/ux.md`, beside `docs/adr/`. **Tracked**, unlike the plan and the PRD.

UI drift is slow drift, and only a diff makes it visible: the question "does
this PR add a component outside the registry" is asked in the PR. A contract
nobody else can read is not a contract. It is also the only part of the steering
documentation a CI job can see, since everything under `.claude/` is private.

Created lazily: a repo that serves no interface has no `docs/ux.md`, and
`verify-ux.sh` exits 0 in silence when the file is absent.

## Shape

```markdown
---
ui_paths: web/templates/**, web/css/**, internal/web/**
fragments: photo-grid.html, photo-card.html, upload-result.html
---

# UX contract

## Direction

One sentence of intent: what someone should remember about this product.
Dense and quiet, built for reading figures quickly, never a standing cockpit.

## Screens

| id | template | dominant action | tension relieved |
|----|----------|-----------------|------------------|
| statement.list | statements.html | open this month's statement | "I don't know where I stand" |
| statement.export | export.html | start the export | "I have to retype it by hand" |

## Components

| block | file | used by | states covered |
|-------|------|---------|----------------|
| b-button | blocks/030-button.css | statement.list, statement.export | default hover disabled loading |
| b-table | blocks/050-table.css | statement.list | default empty loading error |

## Invariants

- Create and edit render the same form partial. <!-- since 2026-07-20 -->
- A low-cardinality tag renders as a chip, never as free text. <!-- since 2026-08-05 -->

## State rules

- An empty state shows the sentinel and one sentence naming the next action, never a bare zero. <!-- since 2026-07-02 -->
- An error state names the failed action and carries a way out. <!-- since 2026-07-02 -->
- Loading shows a skeleton of the final shape, never a full-page spinner. <!-- since 2026-07-02 -->

## Interaction patterns

- Each screen carries one dominant action; the others are visually subordinate. <!-- since 2026-07-12 -->
- Every data list exposes a sort on name. <!-- since 2026-09-03 -->
- A mutation confirms with an auto-dismiss toast, never a blocking modal. <!-- since 2026-08-01 -->

## Token families

Colours, spacing, radii, fonts, durations and z-indices are declared in
`web/css/tokens.css`. This file names no value.
```

## Frontmatter

`ui_paths` makes the loop's gate mechanically conditional: without it, no script
can decide whether a phase touches the interface. Comma-separated globs.

`fragments` lists the templates that are **not** screens: partials, and HTMX
fragments rendered on their own without the layout. Comma-separated basenames,
optional. It has to be declared because no heuristic recovers it. Filename
conventions catch only the obvious cases, and file content is not a signal at
all: in a Go/HTMX codebase every template can open with `{{define}}`, pages
included, so keying on that excludes everything and silently disables the check,
which is worse than the noise it removes. What separates a page from a fragment
is whether the handler composes it with the layout, and only the project knows.

It is also the answer to "does this repo serve an interface": the question is
settled once, at `init`, and written down, so it is never guessed again.

## Sections

| Section | Holds | Verified |
|---|---|---|
| `Direction` | One or two sentences of intent | no, prose |
| `Screens` | id, template, dominant action, tension relieved | yes, against the templates on disk |
| `Components` | block, file, used by, states covered | yes, against `blocks/NNN-*.css` |
| `Invariants` | one rule per line, dated: what keeps features consistent | conflicts detected by judgment |
| `State rules` | one rule per line, dated | conflicts detected by judgment |
| `Interaction patterns` | one rule per line, dated | conflicts detected by judgment |
| `Token families` | a pointer to `tokens.css`, no values | yes, no literal may appear |

**"Dominant action" and "tension relieved" are the two columns that carry the
design intent.** If you cannot fill both, the screen is not designed yet, only
built. That rule comes from `design-system` and is the reason the table
exists at all.

## Rules

**No literal values, anywhere in the file.** No colour, no `px`, no `rem`.
`tokens.css` is the source of truth for values; this file points at it. Without
this rule the contract becomes a stale copy of the stylesheet within six months,
and a stale contract is worse than none. Mechanised by grep.

**One rule per line, short, dated.** The `<!-- since YYYY-MM-DD -->` marker is
what makes the conformance debt computable: it separates "this screen breaks the
rule" from "this screen predates the rule". Without it the warning fires on
everything forever and stops being read.

**No quality score is persisted.** An earlier version of this contract kept the
Readability/Action/Relief grid per screen. It does not survive contact: a script
can only check that a score is *filled*, never that it is *right*, so the gate
is satisfied by a constant, and a constant is what ends up written. Worse, it
forces an edit to the contract on every typo fix in a template, until someone
disables the check. The grid stays where it belongs, in `design-system`,
applied by a person looking at the screen.

## What `verify-ux.sh` checks

Exit 1 on violation, exit 0 in silence when `docs/ux.md` is absent. Modelled on
`verify-adr.sh`.

1. **Every rendered template has a row in `## Screens`, and conversely.** Pure filesystem: template filenames compared to table rows. Deliberately *not* "every served route", which would need a per-framework route parser, produce false positives on dynamic routes, and end up bypassed.
2. **Every `blocks/NNN-*.css` has a row in `## Components`, and conversely.** Bidirectional: catches the component quietly added inside a phase.
3. **No literal value in the file.**
4. **Every declared `ui_path` exists on disk.** A stale path silently disables the gate, which is worse than no gate at all.

## Evolution

Three regimes, which are not handled the same way.

**Mechanical, by the loop, per phase.** A phase that adds a screen adds a row; a
phase that creates a CSS block adds a row. It follows from the diff, and
`verify-ux.sh` makes it mandatory by blocking. Note that a phase which only
*modifies* an existing template writes nothing: only creations and deletions
touch the inventory, which keeps small fixes from turning into contract edits.

**By decision, outside any phase.** A cross-cutting rule ("every data list
exposes a sort on name") applies to everything that follows and may invalidate
what precedes. That is `/10x:plan rule`.

**By correction.** An existing rule turns out wrong or too rigid. Same verb: the
session detects the conflict with what is written and proposes the replacement.

**In bulk, from a source.** Two moments defeat the one-rule-at-a-time form: the
first fill on a repo that already has screens (`rule --from-code`, which reads
the code as the authority and mostly discovers), and a design handoff arriving
mid-project (`rule --from <source>`, where the code is *not* the authority and
the output is mostly conflict). A handoff contradicts the contract on purpose,
so every conflict is arbitrated before anything is written; screens predating a
replaced rule become `backlog` phases. Token values never enter this file: they
belong to `tokens.css`, and `verify-ux.sh` enforces it.

### Conformance debt

When a rule lands, already-shipped screens do not satisfy it. Three possible
behaviours, and the choice decides whether the file stays alive:

- **Block until everything conforms**: guarantees consistency, and guarantees nobody ever adds a rule again.
- **Ignore the past**: the file stays alive, but screens of different generations accumulate, which is the very drift the contract exists to prevent.
- **Record the debt**: the rule applies immediately to new work, non-conforming past becomes `backlog` phases.

The third, which reuses two things that already exist: the `backlog` status, and
the ratchet doctrine of `design-system` (a baseline that only improves,
never lowered to green a build).
