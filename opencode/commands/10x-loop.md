---
description: 'Run one plan-driven work turn: take the first todo phase from the plan file, implement it, prove it with a mutation-checked gate, commit atomically, stop. Never pushes. State lives in the plan file, so the loop resumes after a context clear.'
---

## Usage
`/10x:loop [phase-id | bootstrap] [--plan <path>]`

- No argument: take the first `todo` phase in the resolved plan file.
- `--chain N`: allow up to N phases in one run, stopping at the first that is not green. Each stays its own commit with its own evidence.
- `<phase-id>`: run that specific phase, provided it exists in the plan and its dependencies are `verified`.
- `bootstrap`: no plan yet; mine the repo for existing plans and write one, then stop for approval.
- `--plan <path>`: use this plan file instead of the default resolution. Required when several plans carry `todo` phases.

## Context
- Requested phase: $ARGUMENTS
- Plan resolution: explicit `--plan` path, else `.claude/plan/*.md`, else `./PLAN.md`
- The resolved file is the single source of truth, never the conversation
- Full workflow: `loop` skill
- Commit mechanics: `commit` skill

## Workflow
1. Load the `loop` skill and follow one turn end to end: resolve and state the plan path, read state, confirm the phase is still real, implement, run the verification gate, commit via `commit`, advance the plan file, stop.
2. Report: the phase closed, the quoted evidence from the gate, the next `todo` phase, and anything recorded as a new phase along the way.

## Constraints
- The `loop` skill's Invariants section applies in full (one phase per turn, never push or tag, never widen scope or the dependency surface, never fake a pass, two strikes then halt); this command does not restate it.
- Chaining requires an explicit `--chain N` and stops at the first gate failure, `blocked` phase, or unsatisfied dependency.

## Examples

`/10x:loop bootstrap`
→ Mines docs, ADRs, TODOs and failing tests into `.claude/plan/<slug>.md` with runnable acceptance commands, then stops for approval.

`/10x:loop`
→ Takes the first `todo` phase, writes the failing test, implements, runs `make ci`, mutation-checks the test, commits atomically, marks the phase `verified`.

`/10x:loop P4 --plan .claude/plan/refonte-auth.md`
→ Runs phase P4 of that specific plan, refusing if its dependencies are not yet `verified`.
