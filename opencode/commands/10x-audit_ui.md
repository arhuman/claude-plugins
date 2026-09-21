---
description: 'Run the mechanical CSS-contract audit (tokens, literals, breakpoints, theme-structure, coupling, states, bg-color) on a repo and report the findings as a migration worklist. Read-only except `baseline`, which records the literal-count ratchet.'
model: anthropic/claude-sonnet-4-5
---

## Usage
`/audit_ui`                      run every check on the auto-detected CSS directory
`/audit_ui <check> [css-dir]`    one of: tokens, literals, breakpoints, theme-structure, coupling, states, bg-color
`/audit_ui baseline [css-dir]`   record the current literal count as the ratchet (the one write this command may do)

Deeper than `/check_conform`'s ui.* probes: those measure standard drift; this audits the CSS contract itself.

## Context
- Arguments: $ARGUMENTS
- Runner (not copied into the repo): `skills/design-system/references/audit-ui.sh`
- Contract the checks enforce: `skills/design-system/references/css-contract.md`
- Battery documentation: `skills/design-system/references/quality-guards.md`

## Workflow

1. Load the `design-system` skill.
2. Run `sh skills/design-system/references/audit-ui.sh <subcommand> [css-dir]` from the target repo root. No subcommand given means `all`. If the runner cannot find a CSS directory, ask for the path rather than guessing one.
3. Quote the PASS/FAIL output verbatim. A FAIL line is a lead: confirm one or two findings in the source before presenting counts as verdicts (the checks are grep-grade, and hand-written CSS occasionally defeats them).
4. Present the result grouped as a migration worklist: what blocks now (new drift above baseline), what is frozen debt (under baseline), which check each finding came from, and the single next action (usually `baseline` on a first run, or a plan phase per finding cluster).
5. If the repo has no `make audit-ui` target, say so and offer to wire one (the `makefile` skill owns that change; do not make it inside this command).

## Constraints
- Read-only, with one exception: `baseline` writes `<css-dir>/.audit-ui-baseline` in the target repo, and only when explicitly invoked.
- Never edit CSS to green a check, never lower the baseline, never skip a failing check silently: report it and stop.
- Never vendor the runner into the audited repo; it runs from the plugin. A repo that wants a standing gate copies it deliberately via a plan phase.
- Findings are per the contract in `css-contract.md`; when a repo's own normative doc is stricter (a project css-rules.md), note the difference, do not arbitrate it here.
