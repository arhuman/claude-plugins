# Plan format (contract v1)

The authoritative shape of a plan file. Consumed by `10x-loop` (which executes
phases) and `10x-plan` (which writes and audits them). Neither carries its own
copy: a format described in two places drifts in two directions.

## File resolution

Resolved once per turn, in this order, and the result is stated before any work:

1. An explicit path passed to the command.
2. `.claude/plan/*.md`, the default home. Private working context, gitignored.
3. `PLAN.md` at the repo root, for a plan the repo should carry.

If step 2 finds more than one file carrying a `todo` phase, stop and ask. Never
pick by mtime or alphabetical order.

## Shape

```markdown
# Plan: <project or feature>

Status legend: todo | backlog | doing | verified | blocked

## P1 - <one-line goal>
- Scope: <files or packages this phase may touch>
- New deps: <module paths this phase may add, each naming the function it provides, or none>
- Depends on: <phase ids, or none>
- Refs: <requirement / ADR / screen / issue ids, or none>
- Accept: `<runnable command that decides this phase>`
- Status: todo

## Log
<phase-id> | <status> | <change-id> | <what changed>
```

A bugfix phase carries one extra field, `Repro:` (see below).

## Fields

| Field | Required | Meaning |
|---|---|---|
| `Scope` | yes | The only files this phase may modify. A defect found outside becomes a new phase. |
| `New deps` | yes | Module paths this phase may add, each naming the product function it provides. Default `none`. |
| `Depends on` | yes | Phase ids that must be `verified` first, or `none`. |
| `Refs` | yes | What justifies this phase. `none` is legal. |
| `Repro` | bugfix only | The observed behaviour, in plain language. |
| `Accept` | yes | A command that decides the phase, in backticks. |
| `Status` | yes | One of the legend values. |
| `Claimed-by` | no | `<session-id>@<ISO-8601 timestamp>`, present only while `Status: doing`. Absent means unclaimed. See Claiming a phase. |
| `Attempts` | no | Gate failures under the current claim. Absent means zero. Cleared when the phase reaches `verified` or `blocked`. |

An unknown `- Key: value` line is ignored by readers, which is what keeps this
format forward-compatible: a plan written against a later contract still runs.

## `Refs`

A comma-separated list of typed references. The prefix is the type:

| Form | Target | Resolved by `check` |
|---|---|---|
| `R4` | a row in the Requirements table of `.claude/project/prd.md` | yes, blocking |
| `ADR-0007` | `docs/adr/0007-*.md` | yes, blocking |
| `UX:dashboard` | a row in the Screens table of `docs/ux.md` | yes, blocking |
| `UX:system` | a cross-cutting UI change touching no single screen | yes, blocking |
| `GH-42` | a GitHub issue or discussion | no, always accepted |
| `none` | nothing justifies this phase | n/a, warned |

`GH-<n>` is deliberately never resolved: doing so would need a network call and
a token, which would make verification non-deterministic and useless offline.
It exists to tie a phase to the outside request that caused it, a link that
otherwise lives only in a comment thread.

`none` is legal and produces a warning, never a block. Forcing a refactoring
phase to name a product requirement does not produce traceability, it produces
a fake requirement in the PRD, and the day that happens the system is dead.

`UX:<id>` is mandatory when the phase's `Scope` intersects the `ui_paths`
declared in `docs/ux.md`. That is the only hard obligation, because it is the
only one a script can decide. `UX:system` is the escape hatch for a change that
touches every screen (a token, a layout primitive): naming one screen would be
a lie, naming forty is unworkable, and without the hatch UI refactoring becomes
structurally impossible.

## Status

`todo | backlog | doing | verified | blocked`

- **`todo`**: eligible. The loop takes the first one whose `Depends on` are all `verified`.
- **`backlog`**: invisible to the loop until promoted. Carries "some day", which order alone cannot express: a phase merely pushed to the end of the file still gets picked eventually, one evening, with nobody deciding.
- **`doing`**: claimed by exactly one loop turn, identified by its `Claimed-by` field (see Claiming a phase). A claim is a lease, not a lock: a `doing` phase whose stamp is older than the stale window is eligible again. A `doing` phase with no `Claimed-by` predates this contract or was left by a crash; treat it as stale.
- **`verified`**: closed, with a log line carrying a real change-id.
- **`blocked`**: the gate failed twice on the same diagnosis, or a hard stop fired (drifted golden, unplanned dependency).

## Claiming a phase

Concurrency is optimistic and file-based: no lock server, no daemon. Two
sessions racing the same plan file detect the collision on write-back, never
on read. Run by the loop before any implementation work:

1. Select the first eligible `todo` phase (the ordering rule, unchanged).
2. Write `Status: doing` and `Claimed-by: <session-id>@<timestamp>` to that
   phase immediately, then re-read the file and confirm the stamp survived
   exactly as written. This is the claim.
3. A different `Claimed-by` on re-read means another session won the race.
   That is the protocol working, not an error: the loser has touched no other
   file, so it yields and returns to step 1 for the next eligible phase. Two
   sessions therefore advance two different phases of one plan concurrently.
4. Implement and run the gate as normal.
5. On a gate failure, increment `Attempts` in place, leave `Status: doing`
   and `Claimed-by` unchanged, stop the turn. At `Attempts: 2` set
   `Status: blocked` and clear both claim fields instead: the two-strikes
   count now lives on disk, so it survives a context clear and holds across
   sessions rather than granting each session its own retry budget.
6. On success, set `Status: verified`, clear `Claimed-by` and `Attempts`,
   append the Log line. This is the existing advance write, extended.

**Stale-claim expiry.** A `doing` phase whose `Claimed-by` timestamp is older
than 2 hours is abandoned (a crashed session, a killed turn) and eligible
again, exactly like a `todo`; the reclaiming session appends one Log line
(`reclaimed from stale <session-id>@<timestamp>`) with its own claim. A plan
may override the window with a `Stale-claim-minutes: <n>` line under its
title. Two hours comfortably exceeds the slowest observed gate run while
still recovering same-day from a crash.

Sessions sharing one checkout share one jj working copy, which claiming does
not protect; physical isolation is `concurrency.md` in this directory.

## Phase ids

`P<n>`, unique **per repository**, not per plan file. A new phase takes max+1
over every id present in `.claude/plan/*.md` **and** `.claude/project/archives/`:
archived plans consumed their numbers, and reusing one would collide with the
commit messages and reserves that still cite it. Like requirement ids in the
PRD, a phase id is stable for life: never renumbered, never reused. That is what
makes a bare `P<n>` in a commit message or a cross-plan reserve resolvable with
one grep, long after the plan that held it was archived.

Two consequences, both deliberate:

- A new plan's first phase rarely starts at `P1`. The id identifies, it does
  not rank or count; position in the file carries the order (see Ordering).
- Plans written before this rule may hold duplicate ids across files. They are
  **not renumbered**: rewriting them would falsify the Log lines and commit
  messages that cite them, which costs more than the residual ambiguity. The
  rule binds new phases only, and old collisions die as those plans reach
  `done` and are archived. `verify-plan.sh` surfaces duplicates as warnings,
  never blocks on them: it cannot tell a grandfathered id from a misallocated
  one, and the enforcement point is allocation in `add`, not diagnosis.

## Ordering

**Position in the file is the priority.** The loop reads top to bottom and takes
the first eligible `todo`. Reordering means moving a block.

No priority field is carried, and that is a deliberate choice. A field would
impose a sort, with three costs: the file stops telling the truth about its own
order (you would have to sort mentally to know what runs next); any reader of
the plan and the loop itself must implement the same sort, or one announces a
phase the other does not take; and the default value becomes a trap, since a
phase written without thinking about it lands at the bottom. Position costs none
of that: what you read is what happens.

New phases are appended. An urgent one is inserted **after the last `verified`
phase and before the first `todo`**, never at line 1, which would put it before
closed history and make the log contradict the file. Ids therefore stop being
monotonic (`P12` may precede `P4`), which is harmless: an id identifies, it does
not rank.

## Bugfix phases

A bug reported by a user got past `make ci` by definition: either no test covers
it, or one does and exercises the wrong path. So its `Accept:` names a test that
does not yet do its job, which inverts the rule that governs feature phases.

```markdown
## P7 - Fix: the Blocked badge survives completion
- Scope: internal/web/badge.go, internal/web/badge_test.go
- New deps: none
- Depends on: none
- Refs: GH-42
- Repro: the badge stays visible after the prerequisite task completes (reported 2026-09-01)
- Accept: `go test ./internal/web -run TestBadgeClearsOnCompletion`
- Status: todo
```

`Repro:` carries the observed behaviour: at creation time it is the only thing
that exists. Without a reproduction there is no bug, there is an impression.

**The false red is the trap.** Two ways to fail that have nothing in common:

- `--- FAIL: TestX` (literal `go test` output): the test exists and the behaviour is wrong. A real red: the test catches the bug.
- `no tests to run`, `undefined: TestX`: the test does not exist. A false red, dangerous because it looks like a successful check.

A phase whose `Accept:` "fails" the second way proves nothing. Worse, if the fix
lands without the test being written, the command keeps returning non-zero and
the phase stays red forever, or someone writes an empty test to move on.

Hence the order, which the loop enforces:

1. Write the test reproducing `Repro:`, under the exact name `Accept:` promises.
2. Run it. It must produce a **real** `FAIL`, a failing assertion, not a missing test.
3. Fix.
4. Re-run, green.
5. Mutation check, as for any test-backed phase.

Step 2 is the primary guarantee, and it is stronger than the mutation check:
its "before" is the real bug, not an artificial break.

## Log

One line per event, appended, never rewritten:

```
<phase-id> | <status> | <change-id> | <what changed> | <refs>
```

A plan under `.claude/` is written to disk only, after the commit exists, so it
carries the real change-id. A tracked `PLAN.md` has its status update included
in the phase commit.

## Validity

Every phase must satisfy all of these, and `verify-plan.sh` checks them:

- an `Accept:` that is genuinely runnable in this repo;
- a `New deps` line (`none`, or module paths each naming their function);
- a `Refs` line (`none` counts);
- no `<...>` or `{{...}}` placeholder;
- a status from the legend;
- `Depends on` naming existing phases, without a cycle.

An acceptance criterion no command can decide is not an acceptance criterion:
rewrite it until a command settles it, or split it until one can.
