---
ui_paths: TODO
fragments: TODO
---

# UX contract

<!--
ui_paths: comma-separated globs, the UI surface. Makes the loop gate conditional.
fragments: comma-separated basenames of templates that are NOT screens (partials,
HTMX fragments rendered without the layout). No heuristic recovers this: content
is not a signal, since in a Go/HTMX codebase pages and fragments alike open with
{{define}}. Only the project knows which templates its handlers compose with the
layout, so it declares them here once.
-->

## Direction

TODO: one or two sentences. What should someone remember about this product?

<!--
Not a brief and not a mood board. If the visual direction came from somewhere
else (a design tool, an existing product, a handoff), say where and in one line
what it commits you to. The value of this section is that the next feature can
tell whether it belongs, so "dense, quiet, built for reading figures quickly"
beats any adjective list. If you cannot write it yet, leave the TODO: the tables
below are what the checks read, and they work without it.
-->

## Invariants

<!--
The rules that keep features consistent with each other. This is usually the
section that fills first, because it is what you notice when something is off:
"edit and create use the same form", "a low-cardinality tag renders as a chip".
Write them here through /10x:plan rule, which dates them and lists what breaks.
-->

- TODO <!-- since TODO -->

## Screens

| id | template | dominant action | tension relieved |
|----|----------|-----------------|------------------|
| TODO | TODO.html | TODO | TODO |

<!--
One row per rendered screen. Partials and layouts are not screens.
"Dominant action" and "tension relieved" carry the design intent: if you cannot
fill both, the screen is built, not designed yet.
-->

## Components

| block | file | used by | states covered |
|-------|------|---------|----------------|
| TODO | blocks/NNN-todo.css | TODO | default |

<!--
One row per blocks/NNN-*.css file. Checked both ways: a block with no row and a
row with no block are both violations.
-->

## State rules

- An empty state shows the sentinel and one sentence naming the next action, never a bare zero. <!-- since TODO -->
- An error state names the failed action and carries a way out. <!-- since TODO -->
- Loading shows a skeleton of the final shape, never a full-page spinner. <!-- since TODO -->

## Interaction patterns

- Each screen carries one dominant action; the others are visually subordinate. <!-- since TODO -->

<!--
One rule per line, short, and dated with <!- - since YYYY-MM-DD - ->.
The date is what separates "this screen breaks the rule" from "this screen
predates the rule"; without it the warning fires on everything forever.
Add rules through /10x:plan rule, which dates them and computes the debt.
-->

## Token families

Colours, spacing, radii, fonts, durations and z-indices are declared in
TODO: path to tokens.css. This file names no value: no colour, no px, no rem.
A family absent from that file is not a family.

<!--
Fill every TODO, then delete every instruction comment in this file.
Format contract: ../_shared/references/ux-contract.md
-->
