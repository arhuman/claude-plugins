---
description: 'Run one plan-driven work turn: take the first todo phase from the plan file, implement it, prove it with a mutation-checked gate, commit atomically, stop. Never pushes. State lives in the plan file, so the loop resumes after a context clear.'
argument-hint: "[phase-id | bootstrap] [--plan <path>] [--chain N]"
disable-model-invocation: true
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
- Full workflow: `10x-loop` skill
- Commit mechanics: `10x-commit` skill

## Workflow
1. Load the `10x-loop` skill and follow one turn end to end: resolve and state the plan path, read state, confirm the phase is still real, implement, run the verification gate, commit via `10x-commit`, advance the plan file, stop.
2. Report: the phase closed, the quoted evidence from the gate, the next `todo` phase, and anything recorded as a new phase along the way.

## Constraints
- One phase per turn, then stop. Chaining requires an explicit `--chain N`, and stops at the first gate failure, `blocked` phase, or unsatisfied dependency.
- Never `jj git push`, `git push`, `git tag`, or `make release` - local commits only.
- Never stub, mock, skip, or lower a threshold to reach green; a blocked verification halts the loop.
- Two gate failures on the same phase set it to `blocked` and stop the loop.
- Touch only the current phase's declared scope; defects found elsewhere become new `todo` phases.
- Add no dependency the phase's `New deps` line did not name, and never import a package only present because another dependency pulled it.
- Any claim not backed by a command run this turn is prefixed `UNVERIFIED:`.

## Examples

`/10x:loop bootstrap`
→ Mines docs, ADRs, TODOs and failing tests into `.claude/plan/<slug>.md` with runnable acceptance commands, then stops for approval.

`/10x:loop`
→ Takes the first `todo` phase, writes the failing test, implements, runs `make ci`, mutation-checks the test, commits atomically, marks the phase `verified`.

`/10x:loop P4 --plan .claude/plan/refonte-auth.md`
→ Runs phase P4 of that specific plan, refusing if its dependencies are not yet `verified`.
