# 10x concepts

The vocabulary the plugin uses, defined once. This is the only part of the
catalogue written by hand: commands, skills and agents are derived from their
own frontmatter by `inventory.sh`, because a hand-maintained list drifts and
nothing fails when it does.

Definitions state what a thing **is** and why it exists, not how to use it. The
how lives in the skill that owns it.

## Execution

**Plan.** A markdown file listing the phases of one chantier. Resolved in order:
an explicit `--plan` path, then `.claude/plan/*.md`, then `PLAN.md`. It is the
single source of truth for execution: every fact the next turn needs is in it,
so a context clear costs nothing. It is also the only artifact of this system
that dies, archived when its last phase closes.

**Phase.** One unit of work in a plan: a scope, an acceptance command, a status,
and what justifies it. The loop takes one per turn and stops. Format in
`_shared/references/plan-format.md`.

**Status.** `todo | backlog | doing | verified | blocked`. The loop only takes
`todo`. `backlog` carries "some day", which order alone cannot express: a phase
merely pushed to the end of the file still gets picked eventually, one evening,
with nobody deciding. `doing` is reserved and never written.

**`Refs:`.** What justifies a phase, as typed references: `R4` a PRD
requirement, `ADR-0007` a decision, `UX:dashboard` a screen (`UX:system` for a
cross-cutting UI change), `GH-42` an issue. `none` is legal and only warns:
forcing a refactoring phase to name a requirement produces a fake requirement,
not traceability.

**Ordering.** Position in the file is the priority. No priority field exists, on
purpose: a sort makes the file stop telling the truth about its own order, and
forces two implementations (the loop's and the reader's) to agree forever.

**Verification gate.** The stop criterion of one loop turn, and the reason the
loop is safe to run unattended. Not a report: nothing advances until every item
produced real output. Clean before measuring, run the acceptance command, run
the full check, mutation-check any test-backed phase, treat a skipped test as
red, keep goldens byte-identical, and label anything unproven `UNVERIFIED:`.

**Mutation check.** Break the fix deliberately, confirm the test goes red,
restore. A test that stays green against a broken fix is vacuous. It is what
separates "the suite passed" from "the fix is proven".

**Real red vs false red.** `--- FAIL: TestX` is a failing assertion; `no tests
to run` is a missing test. They look alike to an exit code and mean opposite
things, so a bugfix phase cannot advance on the second.

## Steering documents

**PRD.** `.claude/project/prd.md`, private. Holds the Requirements table with
ids stable for life (`R1..Rn`), never renumbered, never reused. A dropped
requirement moves to `dropped` rather than disappearing, or the `Refs:` of past
phases point at nothing.

**ADR.** `docs/adr/NNNN-slug.md`, tracked, one decision per file, immutable once
accepted. Offered only through a three-part gate: hard to reverse, surprising
without context, the result of a real trade-off. A decision that changes is
superseded by a new file, never amended. Contract v1 in
`grill-with-docs/ADR-FORMAT.md`.

**UX contract.** `docs/ux.md`, tracked. Screens (template, dominant action,
tension relieved), component registry, state rules, invariants. It exists
because `design-system` requires a screen table and a component registry
without ever saying where they live, so the CSS layer had twelve audits and the
intent layer had nothing.

**Glossary.** `CONTEXT.md`, tracked, owned by `grill-with-docs`. The language of
the domain and nothing else: no implementation detail, no spec, no scratchpad.

**Invariant.** A rule in the UX contract that keeps features consistent with
each other ("create and edit render the same form partial"). Distinct from an
aesthetic direction, which is a judgment and is not recorded.

**`since` marker.** The date on a rule. It separates "this screen breaks the
rule" from "this screen predates the rule". Without it the warning fires on
everything forever and stops being read.

**Conformance debt.** What a new rule leaves behind. The rule applies to new
work immediately; non-conforming past becomes `backlog` phases. Blocking until
everything conforms guarantees nobody ever adds a rule again.

## Repo posture

**Ownership.** `owned` or `foreign`, resolved before any write. On a fork or a
third-party checkout the tracked artifacts (`docs/ux.md`, `docs/adr/`,
`CONTRIBUTING.md`) would land in a pull request, proposing methodology the
maintainer never asked for. On `foreign` they move under gitignored `.claude/`,
and the root governance files are never created.

**Profile.** `private | internal | public`, declared as `10x-profile:` in
`CLAUDE.md`. Answers "who consumes this repo", orthogonal to "what kind of
artifact is this". Only governance, release and supply-chain checks vary by it;
security checks never do, because exposure is a property of the deployment.

**Standard.** `_shared/references/standard.yml`, the machine-checkable manifest
of what a conformant repo looks like. Each check carries a severity (P0
security/correctness, P1 parity, P2 polish) and a probe. `standard_version` is
bumped whenever a check is added, removed, or changes severity.

**Drift.** The gap between a repo and the standard, measured by `conform.sh`.
Distinct from code quality, which is graded separately on six axes.

**Tracked vs private.** `.claude/` is the author's working context: intentions,
sequencing, rhythm, nobody else's business, changing too fast to survive review.
`docs/` holds contracts someone else must honour, so they must be readable in a
diff. The split decides what a CI job can even see: `verify-ux.sh` runs in CI,
`verify-plan.sh` cannot and exits 0 when the plan is absent.

## Boundaries

**The loop never pushes.** No `jj git push`, no tag, no release, in any turn,
including to fix CI. Those are the user's manual acts.

**One phase per turn.** The default, and what keeps a rollback cheap. `--chain`
is an explicit, bounded consent to more, never a mode.

**Judgment never blocks.** Only what a script decides produces an exit code.
Everything else is a warning prefixed `UNVERIFIED:`. Turning an appreciation
into a gate produces either circumvention or abandonment.
