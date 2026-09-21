---
ui_paths: TODO
fragments: TODO
---

# UX contract

<!-- Before filling, load ../../_shared/references/ux-contract.md.
ui_paths: comma-separated UI globs that condition the loop gate.
fragments: comma-separated non-screen template basenames (partials/HTMX without
layout). Declare from handler composition, never infer from template content.
-->

## Direction

TODO: one or two sentences stating what users should remember; cite any external
direction source and its commitment. Leave TODO if unknown; tables work without it.

## Invariants

<!-- Cross-feature consistency rules, written/dated through /10x:plan rule. -->
- TODO <!-- since TODO -->

## Screens

| id | template | dominant action | tension relieved |
|----|----------|-----------------|------------------|
| TODO | TODO.html | TODO | TODO |

<!-- One row per rendered screen, excluding partials/layouts. Both intent columns required. -->

## Components

| block | file | used by | states covered |
|-------|------|---------|----------------|
| TODO | blocks/NNN-todo.css | TODO | default |

<!-- One row per blocks/NNN-*.css; missing file or missing row both violate. -->

## State rules

- An empty state shows the sentinel and one sentence naming the next action, never a bare zero. <!-- since TODO -->
- An error state names the failed action and carries a way out. <!-- since TODO -->
- Loading shows a skeleton of the final shape, never a full-page spinner. <!-- since TODO -->

## Interaction patterns

- Each screen carries one dominant action; the others are visually subordinate. <!-- since TODO -->

<!-- One short rule per line; /10x:plan rule dates it (since YYYY-MM-DD) and
computes debt, distinguishing older screens from new violations. -->

## Token families

Colours, spacing, radii, fonts, durations and z-indices: TODO path to tokens.css.
No literal values here (colour, px, rem). Families must exist in that stylesheet.

<!-- Fill every TODO, then remove all instruction comments. -->
