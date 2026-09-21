# 10x concepts

Canonical definitions; usage belongs to owner skills. Commands/skills/agents come from `inventory.sh`, not this glossary.

## Execution

**Plan.** Markdown phases for one chantier; resolve explicit `--plan`, then `.claude/plan/*.md`, then `PLAN.md`. Execution source of truth containing everything the next turn needs after a context clear. Archive when its last phase closes; other system artifacts persist.

**Phase.** One loop-turn unit: scope, acceptance command, status, justification. Format: `_shared/references/plan-format.md`.

**Status.** `todo | backlog | doing | verified | blocked`. Only `todo` is executable; `backlog` explicitly defers work. `doing` is reserved, never written.

**`Refs:`.** Typed phase justification: `R4` requirement, `ADR-0007` decision, `UX:dashboard` screen (`UX:system` cross-cutting UI), `GH-42` issue. `none` is legal and only warns.

**Ordering.** File position is priority; no priority field.

**Verification gate.** Nothing advances without real output: clean before measurement, acceptance command, full check, mutation check for test-backed phases. Skips are red; goldens stay byte-identical; label unproven claims `UNVERIFIED:`.

**Mutation check.** Deliberately break the fix, observe red, restore. Remaining green means a vacuous test.

**Real red vs false red.** `--- FAIL: TestX` proves a failing assertion; `no tests to run` means missing test and cannot advance a bugfix.

## Steering documents

**PRD.** Private `.claude/project/prd.md` Requirements table. IDs `R1..Rn` never change or get reused; dropped requirements become `dropped`, never disappear.

**ADR.** Tracked `docs/adr/NNNN-slug.md`, one decision per file, immutable once accepted. Offer through the three-part gate: hard to reverse, surprising without context, real trade-off. Changed decisions get a superseding file, never amendment. Contract: `steering/references/ADR-FORMAT.md`.

**UX contract.** Tracked `docs/ux.md`: screens (template, dominant action, tension relieved), components, state rules, invariants; records design-system intent.

**Glossary.** Tracked `CONTEXT.md`, owned by steering: domain language only, no implementation detail/spec/scratchpad. Shape: `steering/references/CONTEXT-FORMAT.md`.

**Invariant.** UX-contract consistency rule across features, distinct from unrecorded aesthetic judgment.

**`since` marker.** Rule date distinguishing violations from screens predating the rule.

**Conformance debt.** New rules apply immediately to new work; nonconforming past becomes `backlog`, not a blocker.

## Repo posture

**Ownership.** `owned | foreign`, resolved before writing. On foreign/fork/third-party repos, tracked methodology artifacts (`docs/ux.md`, `docs/adr/`, `CONTRIBUTING.md`) move under gitignored `.claude/`; never create root governance files.

**Profile.** `private | internal | public` via `10x-profile:` in CLAUDE.md: audience, independent of artifact type. Only governance, release and supply-chain checks vary; security checks never do.

**Standard.** `_shared/references/standard.yml`: probes and severities P0 security/correctness, P1 parity, P2 polish. Bump `standard_version` when adding/removing checks or changing severity.

**Drift.** Gap from standard measured by `conform.sh`, distinct from six-axis code quality.

**Tracked vs private.** `.claude/` is private working context; `docs/` holds reviewable contracts. `verify-ux.sh` runs in CI; `verify-plan.sh` cannot and exits 0 with no plan.

## Boundaries

**The loop never pushes.** No `jj git push`, tag or release, even to fix CI; these are user manual actions.

**One phase per turn.** Default; `--chain` is explicit bounded consent to more, never a mode.

**Judgment never blocks.** Only script-decided checks produce exit codes; other assessments warn with `UNVERIFIED:`.
