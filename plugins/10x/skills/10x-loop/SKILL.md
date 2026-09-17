---
name: 10x-loop
description: 'Autonomous plan-driven work loop: read the plan file (an explicit path, else .claude/plan/*.md, else PLAN.md), take the first todo phase, implement it, prove it with a mutation-checked verification gate, commit atomically, stop. State lives on disk (plan file + repo), never in the conversation, so the loop survives a context clear and resumes on the next turn. Use when running unattended or resumable multi-phase work, when asked "what is next" against a plan, or to bootstrap a plan from an existing roadmap. Not for a one-shot implementation with no plan file: implement directly and use 10x-commit.'
---

# 10x Loop

A loop is only as safe as the wall it stops at. The failure mode this skill
exists to prevent is not an agent that does too little, it is an agent that runs
all night producing plausible, green, wrong work: a test that silently skipped
on a bad path, a substitution that ran twice, a claim asserted instead of
measured. So the loop below is two loops nested: an outer loop that advances one
phase per turn, and an inner verification gate that must produce *evidence* before
the outer loop is allowed to move. The gate is the stop criterion. Without it,
do not run this skill.

State lives on disk. Every fact the next turn needs is in the plan file or the
repo, never in conversation history. That is what makes the loop resumable after
a context clear, and it is the constraint that makes the rest work.

## The plan file

Resolved once per turn, in this order, and the result is reported before any
work starts:

1. An explicit path passed to the command, when given.
2. `.claude/plan/*.md` - the default home. Private working context, consistent with `.claude/doc/`, and not published with the repo.
3. `PLAN.md` at the repo root, for a plan meant to be tracked and shared.

If step 2 finds more than one file carrying a `todo` phase, stop and ask which
one. Never pick by mtime or alphabetical order: guessing which chantier the user
meant is exactly the failure this skill exists to prevent, and two plans racing
on one repo corrupt both.

`.claude/` is gitignored, so a plan living there is never part of a commit. Step
6 still rewrites the file on disk (that is the durable state), but the commit
carries only source changes, and the phase's log line references the change-id
rather than the reverse. A plan under `PLAN.md` is tracked and its status update
belongs in the phase commit.

**Done when:** the resolved plan path is stated back before the first edit, and
exactly one file was selected.

## Invariants

These hold at every turn, and they are not negotiable by the loop itself.
Running more than one loop concurrently against the same repo additionally
requires one jj workspace per session, per
`../_shared/references/concurrency.md`: the claim protocol keeps two sessions
off the same phase, not off the same working copy.

- **One phase per turn.** Take the first `todo` phase in the plan file, finish it, stop. Never chain two phases in one turn, however small the second looks. Chaining is how a scope grows past the point where a rollback is cheap. The single exception is an explicit `--chain N` (below), which is bounded consent, never a mode.
- **Never push. Never tag.** The loop commits locally and stops. `jj git push`, `git push`, tags, and `make release` are the user's manual act, and no loop turn may perform them, including to "fix CI".
- **Never widen scope.** Touch only the files the current phase names. A defect found elsewhere is recorded as a new `todo` phase in the plan file, never fixed inline. A toolchain, dependency, or architecture change is never a side effect of a phase.
- **Never widen the dependency surface.** A phase may add a direct dependency only if the plan file names it in that phase's scope. This is separate from file scope above: a loop is a creep machine, because every phase has a locally valid reason to pull one more package and no view of the cumulative surface. An unplanned dependency halts the phase and becomes the user's decision, never a side effect.
- **Never fake a pass.** No stub, no mock, no skip, no lowered threshold, no deleted assertion to get to green. A blocked verification is reported and the loop halts (`blocked` status); it is never routed around.
- **Two strikes, then halt.** If the verification gate fails twice on the same phase, set that phase to `blocked` with the failing output quoted, and stop the loop. A third attempt on an unchanged diagnosis is thrashing, not progress. Each failure increments the phase's `Attempts` field on disk (per plan-format.md), so the count survives a context clear and holds across sessions instead of granting every session its own retry budget.

## Loop turn

### 0. Open the turn on a fresh change

In jj the working copy **is** a commit. After a `jj describe`, `@` stays that
described commit, and the next edit amends it silently: no error, no prompt,
two phases fused into one commit, a `jj split` to pay later. This exact miss
produced three mixed commits and five repair splits in one production repo
before this gate existed.

Before touching any file:

```
jj log -r @ --no-graph -T 'if(description, "described", "undescribed")'
jj diff -r @ --stat
```

- `@` described (whether or not it has changes): run `jj new` first. The
  previous turn forgot to; this turn does not inherit its commit.
- `@` undescribed but non-empty: stop and report the leftover files. They
  belong to no phase, and starting anyway would bundle them into this one.
- `@` undescribed and empty: proceed.

**Done when:** the two commands above were run this turn and `@` is an empty,
undescribed change.

### 1. Read state

Resolve the plan file per the section above, state the path, then take the first
phase whose status is `todo`.

Claim it before any other work: write `Status: doing` plus a `Claimed-by`
stamp and re-read the file to confirm this session's claim survived, per
`../_shared/references/plan-format.md`'s Claiming a phase section (which also
owns the stale-claim window and the lost-race rule). A lost race is not an
error: yield and take the next eligible phase instead.

A phase whose `Depends on` names a phase that is not `verified` is not eligible,
however early it appears in the file: skip to the next `todo` and state the
skip. If no phase is eligible, stop and name the blocking dependency; when that
dependency sits in `backlog`, say it must be promoted first. Position in the
file is the priority, so nothing else reorders the queue.

`backlog` joins `verified` and `blocked` among the statuses the loop ignores. It
carries "some day", which order alone cannot express.

Never invent a phase, a label, or an acceptance criterion that is not written in
the plan file. If the user names a phase absent from the file, stop and say so
rather than guessing what it meant: an invented label is how a plan silently
forks from the work.

If the plan file does not exist, run the Bootstrap section instead of this turn.

**Done when:** exactly one phase is selected, its id and acceptance command are
quoted back, that command string appears verbatim in the plan file, and this
session's `Claimed-by` stamp survived the post-write re-read (or the next
eligible phase was taken after a lost race).

### 2. Confirm the phase is still real

Before writing anything, check the phase against the code. A phase written last
week may already be satisfied, or its premise may have moved. Read the files it
names.

If the acceptance command already passes, set the phase to `verified` without
writing code, note "already satisfied" in the log line, and stop the turn.

When the phase renames an exported symbol, changes its signature, or moves it,
measure the blast radius before the first edit: `findReferences` (or
`incomingCalls` for a function) on the symbol, per
`../_shared/references/lsp-navigation.md`, and confront every site against the
phase's `Scope`. A site outside the scope means the phase is under-sized:
stop, record the missing files in the plan (widen this phase's scope or add a
`todo` phase), and do not start a diff that is known incomplete. Grep does not
satisfy this check on a common name; if no language server answers, the
fallback list is produced and the conclusion carries `UNVERIFIED:` per the
same reference.

**Done when:** either the acceptance command has been run and failed (the phase
is real work), or it passed and the phase was closed without an edit; and, for
a phase touching an exported symbol, the reference list was produced and every
listed site falls inside the phase's scope (or the phase was stopped as
under-sized).

### 3. Implement

Apply the phase, and only the phase.

For a bugfix phase, write the failing test first and show its red output before
touching the fix. A fix written before the test that catches it is a fix whose
test is unproven.

That red must be a **real** one. `no tests to run` and `undefined: TestX` are
not failures, they are a missing test, and they look exactly like a successful
check. A bug reported by a user got past `make ci` by definition, so its test
either does not exist or exercises the wrong path; the phase cannot advance
until the output shows an assertion failing. Otherwise the fix lands, the
command keeps returning non-zero, and the phase stays red forever or someone
writes an empty test to move on.

That failing test is the one test this loop writes itself, scoped to the
phase's `Repro:`. A phase needing a broader test strategy, coverage analysis,
or a non-bugfix suite delegates to `tester-agent`, which applies `10x-tester`.

Delegate per the user's routing when the phase is large: `coder-agent` for
non-trivial Go/TypeScript, `fixer-agent` for mechanical fully-specified edits.
A delegate's claim alone is never evidence, per `coder-agent`'s Delegation
rule: verify with the gate below like any other work.

**Done when:** `jj diff --stat` lists only files within the phase's declared
scope, and no file outside it was modified. Two named exceptions, and they are
exceptions, not a general loosening:

- `docs/ux.md` is legal in the diff when the phase touches the `ui_paths` it declares, without being listed in `Scope`. A UI phase has to record its screen or its component in the contract, and that file is never in its own scope, so without this exception every UI phase fails here.
- The test file covering a source file already in `Scope` is legal without being listed. Step 3 *mandates* a failing test first on a bugfix phase, and a `Scope` written around the defect names the source file, so without this exception the gate rejects the very test it just required: the phase fixes the bug correctly and then fails on the artefact proving it. This covers the test beside the scoped file, not a new test package, and never a second source file.

### 4. Verification gate

This is the stop criterion. It is a gate, not a report: the loop may not
advance until every item below produced real output.

1. **Clean first, then measure.** Remove stale artifacts before any count or benchmark (`go clean -cache` where relevant, `find . -name '*.pyc' -delete`, regenerate goldens). A number measured over stale artifacts is not a number.
2. **Run the phase's acceptance command**, then the repo's full check (`make ci` where it exists, else `make fulltest`, else the project's test+lint command). Paste the real output. Never predict output, never summarize a run that was not executed. **The full check runs here, once, at the gate, never inside the red/green iteration**: while iterating on the implementation, use the targeted test and `make test` (short units, seconds). Measured on a real repo, a full check run per iteration cost 300s a time for 36s of tests, dozens of times a night.
3. **Mutation check.** For any phase whose acceptance rests on a test: break the fix deliberately, re-run that test, confirm it goes red, restore. A test that stays green against a broken fix is vacuous and proves nothing. Quote both runs.
4. **A skipped test is a failure.** Treat `SKIP` as red, not as absence of red. Report which test skipped and why.
5. **Goldens stay byte-identical.** If a phase changes golden output, that is a hard stop, not a regeneration. Report the drift and mark the phase `blocked`.
6. **A touched migration chain replays from zero.** If `jj diff --stat` lists a file under the repo's migration directory, apply the *whole* chain to an empty volume and restart the stack, quoting both. The full check does not cover this: it builds its test database by replaying every migration in the new order onto nothing, which succeeds, while what breaks is an existing volume replaying only the tail. A constraint added before the rename or backfill it depends on passes here and breaks every deployed database, so a failure is a hard stop that marks the phase `blocked`, never a reordering waved through on the argument that a fresh build was green.
7. **Dependency surface unchanged, or planned.** A non-empty `jj diff go.mod go.sum` (or the ecosystem's manifest) in a phase whose scope did not name that dependency is a hard stop, like a drifted golden: mark the phase `blocked` and report the added module. Then run the promotion check below; it must print nothing.
8. **Label what you could not verify.** Any claim not backed by a command executed this turn is prefixed `UNVERIFIED:`. Never argue for a position that was not tested.
9. **References resolve, and the UI contract holds.** Run `../10x-plan/references/verify-plan.sh` on the resolved plan: every id in the phase's `Refs` line must point at a real target, and an id naming a `deprecated` or `superseded` ADR is a hard stop, like a drifted golden, because it means the phase implements a decision that has been replaced. If the phase's `Scope` intersects the `ui_paths` declared in `docs/ux.md`, also run `../10x-plan/references/verify-ux.sh`: it must exit 0, and the phase must carry a `UX:` ref (a screen id, or `system` for a cross-cutting change). A repo with no `docs/ux.md` skips this second half entirely.

The promotion check catches the one move that lengthens the chain under your own
roof: a package present only because something else pulled it (structural,
inherited, nobody chose it) getting imported directly by your code, which
silently promotes it to functional without anyone arbitrating it. It then starts
pulling *its* structural dependencies into your responsibility. Zero is the only
acceptable output.

The command below is Go-only: run it when the repo has a `go.mod`, and skip it
otherwise rather than reporting its failure as a gate result. An error from `go
list` in a TypeScript or Python repo means the check did not apply, not that the
surface drifted, and "printed nothing because it could not run" is the one way
this item silently passes while checking nothing. On another ecosystem, apply the
same rule by hand against that manifest's direct-dependency list, or label the
item `UNVERIFIED:` per item 8.

```bash
SELF=$(go list -m)
comm -13 \
  <(go mod edit -json | python3 -c 'import json,sys; d=json.load(sys.stdin); [print(r["Path"]) for r in (d.get("Require") or []) if not r.get("Indirect")]' | sort) \
  <(go list -deps -f '{{if .Module}}{{.Module.Path}}{{end}}' ./... | sort -u) \
  | grep -v "^${SELF}$"
```

Depth is the metric, not count. Structural depth is unbounded and none of your
business: a JWT library pulling six layers of crypto is that library doing its
job. Functional depth is bounded to 1, because each functional dependency
answers a function *your* product requires, and has no right to pull a second
one into your perimeter. "Functional pulling functional" is the creep, and this
catches it at level 2 rather than level 4.

The same rule governs added code, where no manifest makes the creep visible: a
package created to support another one is structural and must never be imported
by a third. Enforce it with placement rather than convention - a support package
under `internal/<owner>/internal/` is a compile error for anyone else, not a
guideline. That is how `internal/authutil` avoids becoming the next `common`.

**Done when:** the acceptance command exited 0 with its output quoted; the full
check exited 0 with its output quoted; for a test-backed phase, both the broken
run (red) and the restored run (green) are quoted; no test reported skipped; for
a phase touching migrations, the full-chain replay onto an empty volume and the
stack restart both exited 0 with their output quoted; the
promotion check printed nothing and `jj diff go.mod go.sum` is empty unless the
phase's scope named the added dependency; and the working copy contains no
leftover deliberate breakage (`jj diff` shows only the intended change).

### 5. Commit

Apply the `10x-commit` skill in full: it owns jj mechanics, message composition,
the `--stdin` heredoc rule, and the tracked-`CHANGELOG.md` obligation for
`feat`/`fix`/`perf`. Do not restate or re-derive those rules here.

One phase is one atomic commit. If the phase produced changes that belong in
separate commits, `jj split` them per that skill rather than bundling.

The commit step ends with `jj new`, never with the describe: a described `@`
left as the working copy silently absorbs the next turn's first edit (see
step 0). A turn that stops before `jj new` has not finished committing.

**Done when:** `10x-commit`'s own Done-when block passes, no push or tag
command was run this turn, and `jj log -r @ --no-graph -T description` prints
nothing: a fresh empty change is open on top of the phase commit.

### 6. Advance state and stop

Set the phase's status to `verified` in the plan file, clear its `Claimed-by`
and `Attempts` fields, and append a log line
(`<phase-id> | verified | <commit change-id> | <one-line what> | <refs>`). The
refs carried over from the phase are what make the log readable as a product
trace and not only as a technical one. A tracked
`PLAN.md` update belongs in the phase commit; a plan under `.claude/` is written
to disk only, so write it after the commit exists and record the real change-id.

Then stop and report: the phase closed, the evidence, the next `todo` phase, and
anything recorded as a new phase along the way.

**Done when:** the plan file shows the phase as `verified` with a log line carrying a
real change-id; the next turn can start from the file alone with no conversation
context.

## Chaining (`--chain N`)

`--chain N` allows up to N phases in one run. It exists because a run of
mechanical phases costs one prompt each for no judgment in between, and that is
real friction. It stays opt-in and bounded because the one-phase default is what
keeps a rollback cheap.

The gate is unchanged and runs in full on every phase. What changes is only what
happens after a green one.

- **Stop on the first failure.** A gate failure, a `blocked` phase, or a phase whose dependencies are not `verified` ends the chain there. Never move to phase N+1 to "make progress" while N is red: two failures on two different phases is a run nobody can unwind.
- **One phase is still one commit.** Chaining changes the number of turns, never the granularity of history. No squashing, no combined message.
- **Report every phase, with its evidence.** The final report lists the N phases and the quoted output that closed each one, not just the last. A chain whose middle is unproven is a chain that proved nothing.
- **The plan file is written after each phase**, not once at the end. An interrupted chain must leave the same state a sequence of single turns would have left.

**Done when:** the chain stopped at N phases or at the first non-green one,
whichever came first; each closed phase has its own commit and its own quoted
evidence; the plan file reflects every phase closed, not only the last.

## Bootstrap (no plan file yet)

Scaffolding a project and writing its first plan belongs to `10x-plan`: run
`/10x:plan init`, which creates the context scaffold, the UX contract when the
repo serves an interface, and an empty plan, then stops for approval. This skill
executes phases; it does not own the documents they cite.

When invoked with no plan and `10x-plan` is unavailable, mine what already
exists rather than inventing a roadmap: existing plan docs, `.claude/project/`,
`docs/adr/`, TODOs, failing tests, open conformance findings. Write to
`.claude/plan/<slug>.md` by default, or to the explicit path when one was given;
use a tracked `PLAN.md` only when the user asks for a plan the repo should
carry. Then stop. Do not implement a phase in the same turn that creates the
plan: the user approves it before the loop runs against it. A tracked `PLAN.md`
is committed alone; a plan under `.claude/` is gitignored and stays uncommitted,
which is expected, not a missing step.

Each phase carries the fields defined in
`../_shared/references/plan-format.md`: a stable id, a one-line goal, the files
in scope, the module paths it may add (default `none`, each naming the function
it provides), what justifies it (`Refs:`), a genuinely runnable acceptance
command, dependencies on other phase ids, and a status.

A dependency nobody can tie to a required function does not belong in a phase.
The question that settles it: which product function disappears if this is
removed? "None, but it stops compiling" means structural, and it stays invisible
in the manifest of whatever pulled it. "None, actually" means it goes.

An acceptance criterion that no command can decide is not an acceptance
criterion: rewrite it until a command settles it, or split it until one can.

**Done when:** every phase in the written file has a runnable acceptance command,
a `New deps` line (`none`, or module paths each naming the function it provides)
and a `Refs` line (`none` counts), no phase carries a `<...>` or `{{...}}`
placeholder, `verify-plan.sh` exits 0 on the written file, and the written path
was stated back; a tracked `PLAN.md` was committed alone, a plan under
`.claude/` was not committed at all.

## PLAN.md template

Fill every placeholder, then delete this instruction line and the template's
angle brackets.

The authoritative format, fields included, is
`../_shared/references/plan-format.md`. It is held there once because two skills
read it. What follows is the shape to copy.

```markdown
# Plan: <project or feature>

Status legend: todo | backlog | doing | verified | blocked

## P1 - <one-line goal>
- Scope: <files or packages this phase may touch>
- New deps: <module paths this phase may add, with the required function each one provides, or none>
- Depends on: <phase ids, or none>
- Refs: <requirement / ADR / screen / issue ids, or none>
- Accept: `<runnable command that decides this phase>`
- Status: todo

## P2 - <one-line goal>
- Scope: <...>
- New deps: none
- Depends on: P1
- Refs: none
- Accept: `<...>`
- Status: todo

## Log
<phase-id> | <status> | <change-id> | <what changed> | <refs>
```

`Refs:` ties a phase to what justifies it: `R4` a PRD requirement, `ADR-0007` a
decision, `UX:dashboard` a screen (`UX:system` for a cross-cutting UI change),
`GH-42` an issue. `none` is legal and only warns: forcing a refactoring phase to
name a requirement produces a fake requirement, not traceability.

A bugfix phase adds `Repro:`, the observed behaviour in plain language.

## MUST NOT

- Run `jj git push`, `git push`, `git tag`, or `make release` in any turn.
- Advance a phase on a self-reported pass with no command output quoted.
- Chain a second phase into the same turn because the first finished early.
- Fix a defect found outside the current phase's scope; record it as a new phase.
- Stub, mock, skip, or lower a threshold to reach green.
- Regenerate a golden that drifted; that is a `blocked` phase.
- Add a direct dependency the phase's scope did not name, or import a package that is only present because another dependency pulled it.
- Let a type from an external dependency appear in the signature of an exported domain symbol; that colonizes the API and makes the dependency unremovable.
- Retry a failing phase a third time after two gate failures on the same diagnosis.
- Write a phase label or acceptance criterion that the user did not approve in the plan file.
