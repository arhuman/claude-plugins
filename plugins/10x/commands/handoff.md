---
description: 'Save or restore the thread of an interrupted phase. Writes .claude/handoff.md with where the work stands and what comes next, or reads it back and reconciles it against the repo. Private, never tracked.'
argument-hint: "[--resume]"
disable-model-invocation: true
---

## Usage
`/10x:handoff` writes the handoff. `/10x:handoff --resume` reads it back.

The plan already makes the loop resumable **between** phases: every fact the
next turn needs is in the file. This covers the other case, a phase interrupted
**in the middle**, where all that survives is a diff and none of the reasoning
behind it.

Not `/design_handoff`: that command assembles an outbound design brief and
gates the returned deliverable; it does not save or resume work state.

## Context
- Mode: $ARGUMENTS
- Handoff file: `.claude/handoff.md` (lifecycle contract: `skills/_shared/references/artifacts.md`)
- Plan resolution: explicit path, else `.claude/plan/*.md`, else `PLAN.md`
- Phase format: `skills/_shared/references/plan-format.md`

## Workflow

### Writing (no argument)
1. Resolve the plan, state the path, and name the phase in progress.
2. Read the repo, do not ask: `jj status`, `jj diff --stat`, and the last few `jj log` entries.
3. Write `.claude/handoff.md` with: the phase and its acceptance command; what is done and what is not, at the level of the phase's own tasks; the files touched with why; the next concrete action; open questions and anything you were about to verify.
4. State the path written and the phase it covers.

### Resuming (`--resume`)
1. Read `.claude/handoff.md`. If it is absent, say so and fall back to the plan alone.
2. **Reconcile it against the repo before trusting it.** Compare its file list to `jj diff --stat` and its phase to the plan's current statuses. Work may have happened since it was written, or the phase may have been closed by another turn.
3. Report: where the work stands, what the handoff claims, and **any point where the two disagree**. A silent stale handoff is worse than none.
4. Name the next action and stop. Do not resume the work in the same turn.

## Constraints
- Write only `.claude/handoff.md`. Never touch the plan, the code, or any tracked file.
- Never invent progress the repo does not show. "Task 3 in progress" needs a diff that supports it.
- On `--resume`, never recite the file without checking it against the repo.
- Do not implement anything, in either mode. This command hands over; `/10x:loop` works.

## Examples

`/10x:handoff`
Mid-phase, before a break: records that the failing test is written and red, the fix is half applied, and the mutation check has not run yet.

`/10x:handoff --resume`
New session: restores the thread, and warns if the two commits made since were not in the handoff.
