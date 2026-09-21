---
description: 'Steering documentation for agentic work: bootstrap the project scaffold and plan, add or promote a phase, report status, file a cross-cutting rule in the right document, or audit the whole set for inconsistency. Writes documents and plans; never executes a phase.'
---

## Usage
`/10x:plan <verb> [args]`

| Verb | Does |
|---|---|
| `init` | Creates the scaffold (PRD, tech notes, UX contract, empty plan), normalizes requirement ids, notifies mnemos. Invents nothing. |
| `status` | Read only. Phase counts, the phase the loop would take next, blocked phases, uncovered requirements. |
| `add "<goal>"` | Adds one phase. `--urgent` inserts before the first `todo`, `--backlog` parks it, `--promote <id>` does the reverse. |
| `rule "<rule>"` | Short session: detects conflicts, lifts ambiguity, routes to `docs/ux.md`, an ADR, `tech.md` or `CONTEXT.md`, dates the line, computes the conformance debt. |
| `rule --from-code` | Reads the existing UI and proposes the whole contract (screens, components, invariants it finds repeated). You approve line by line. |
| `rule --from <src>` | Absorbs a design handoff: surfaces every conflict with the current contract first, then the additions, then the migration debt. |
| `done` | Closes a finished chantier: refuses unless every phase is `verified`, writes the summary, archives the plan, retires the mnemos pointer, lists the `backlog` residue. |
| `check` | Diagnosis only. Runs the two verifiers, relays ADR conformance, adds judgment warnings. Repairs nothing. |

To execute a phase, use `/10x:loop`.

## Context
- Request: $ARGUMENTS
- Full workflow: `steering` skill
- Plan and phase format: `~/.config/opencode/skills/_shared/references/plan-format.md`
- UX contract format: `~/.config/opencode/skills/_shared/references/ux-contract.md`
- Verifiers: `skills/steering/references/verify-plan.sh`, `verify-ux.sh`
- Ownership: `skills/steering/references/ownership.sh` (owned vs foreign repo)
- Plan resolution: explicit `--plan` path, else `.claude/plan/*.md`, else `PLAN.md`

## Workflow
1. Load the `steering` skill and run the requested verb end to end, following its Done-when block.
2. State the resolved plan path before any write.
3. Report: what was written and where, the verifier output quoted verbatim when one ran, and what needs the user's decision.

## Constraints
- Never execute a phase; that is `/10x:loop`.
- Never invent a requirement, phase, screen or rule the user did not approve. Propose and ask.
- Never create a second requirements document, nor a decisions file beside `docs/adr/`.
- Blocking is reserved for what a script decides. Judgment is reported as `UNVERIFIED:`.
- `check` diagnoses; it never repairs.
- Never write a tracked file into a repo that is not ours: on a fork or a third-party checkout the steering documents move under `.claude/`, and `CONTRIBUTING.md` / `SECURITY.md` are never created. State the ownership verdict before writing.
- Never push, tag, or release.

## Examples

`/10x:plan init`
Creates `.claude/project/`, `.claude/CHANGELOG.md`, an empty plan, and `docs/ux.md` if the repo serves an interface. Stops for the user to fill the PRD.

`/10x:plan add --urgent "the Blocked badge survives completion"`
Writes a bugfix phase with its `Repro:`, inserted before the first `todo`, after checking that the named test does not yet cover the case.

`/10x:plan rule --from-code`
On a repo that already has screens, derives the Screens and Components tables from disk and proposes the invariants it finds repeated ("create and edit share one form partial", "low-cardinality tags render as chips"), each with the files that evidence it. Nothing is written without approval.

`/10x:plan rule --from docs/handoff-v2.md`
Mid-project style change. Checks each implied rule against what the contract already says ("the contract says mutations use a toast since 2026-08-01, the handoff puts editing in a side panel: replace, or do both stand?"), offers one ADR for the direction change, then turns the screens predating each replaced rule into backlog phases. Token values go to `tokens.css`, never into the contract.

`/10x:plan rule "every data list exposes a sort on name"`
Asks only if it conflicts with an existing rule or if the wording is ambiguous, then files it in `docs/ux.md` with a `since` marker and lists the screens that predate it.

`/10x:plan done`
Refuses while phases remain open, listing them. Once all are `verified`, writes the summary, archives the plan under `.claude/project/archives/`, and names the backlog phases that die with it.

`/10x:plan check`
Runs both verifiers, reports unresolvable references, dependency cycles, UI phases with no `UX:` ref, and uncovered `must` requirements.
