---
name: loop
description: 'Execute one approved plan phase autonomously, prove it with a mutation-checked gate, commit locally, and stop. Resolve an explicit plan path, else .claude/plan/*.md, else PLAN.md. Disk state survives context clears. Use for unattended/resumable multi-phase work, finding the next planned phase, or bootstrapping from an existing roadmap. For one-shot work without a plan, implement directly and use commit.'
---

# 10x Loop

The plan and repo hold all resumable state. No phase advances without executed verification evidence.

## The plan file

Before work, load `../_shared/references/plan-format.md` for resolution, fields, eligibility, claims, retries, ids and log format. Resolve once: explicit path, else `.claude/plan/*.md`, else root `PLAN.md`. If multiple private plans carry `todo`, stop and ask; never choose by mtime or alphabet. State exactly one resolved path before editing. If absent, Bootstrap instead.

Private `.claude/` plans stay uncommitted; write their durable status after the commit exists, citing its change-id. A tracked `PLAN.md` status update belongs in the phase commit.

## Invariants

- One phase per turn, then stop. Only explicit `--chain N` relaxes this, with bounded consent.
- Never publish: no push, tag, or `make release`, even to fix CI.
- Modify only the phase's named files, except the two implementation exceptions below. Record outside defects as new `todo` phases, never fix them inline. No incidental toolchain, dependency or architecture changes.
- Add a direct dependency only when that phase names it. Unplanned dependencies halt for the user's decision. Never expose external dependency types in exported domain signatures.
- No stub, mock, skip, threshold reduction or assertion deletion to reach green. Blocked verification halts with `blocked` status.
- Two gate failures on the same diagnosis exhaust the budget. Persist each failure in `Attempts`; never reset the budget on context clear or session change. Follow the shared claim contract: first failure leaves `doing` and `Claimed-by`, stops the turn; second sets `blocked`, quotes failing output and clears claim fields. Hard stops block immediately.
- Concurrent sessions require one isolated jj workspace each. Before concurrent work, load `../_shared/references/concurrency.md`; claims isolate phases, not working copies.

## Loop turn

### 0. Open the turn on a fresh change

Before touching files, run both:

```sh
jj log -r @ --no-graph -T 'if(description, "described", "undescribed")'
jj diff -r @ --stat
```

Described `@`: `jj new`, even if empty. Undescribed but non-empty: stop and report leftover files. Proceed only with empty, undescribed `@`; otherwise new edits silently amend prior work.

### 1. Read state

Read the resolved plan. Take the first eligible `todo` in file order: all `Depends on` must be `verified`. State dependency skips; if none eligible, stop naming blockers, including any `backlog` dependency that needs promotion. Ignore `backlog`, `verified`, `blocked`; stale `doing` recovery follows the loaded claim contract (including its stale window, overrides and legacy claims).

Never invent a phase, label or acceptance criterion. A requested phase absent from the plan is a stop.

Before other work, acquire:

```sh
token=$(../_shared/references/claim.sh acquire <plan> <phase-id> "$SESSION")
```

Non-zero: lost race, yield and try the next eligible phase without editing other files. On success retain the opaque token throughout the turn for renew/verify; claim release and stale reclaim use the shared protocol, never a hand-written claim. Quote the selected id and its verbatim acceptance command from the plan. Proceed only with exactly one phase and a successful claim.

### 2. Confirm the phase is still real

Read scoped files and run acceptance before implementation. If it already passes, close as `verified`, log "already satisfied", perform step 6's token check and state cleanup, and stop without code changes.

For an exported symbol rename, signature change or move, load `../_shared/references/lsp-navigation.md`; run `findReferences` (or function `incomingCalls`) before editing. Confront every site with `Scope`. Outside sites: stop, record missing files by widening the plan scope or adding a `todo`, never start a known-incomplete diff. Grep alone cannot verify a common name; absent a language server, produce the prescribed fallback list and label the conclusion `UNVERIFIED:`.

Proceed only after acceptance failed and, where applicable, all reference sites fit the scope; otherwise close or stop as above.

### 3. Implement

Implement only the phase. For bugfixes, first write the test named by `Accept:` reproducing `Repro:` and quote an actual failing assertion before fixing. `no tests to run` or `undefined: TestX` proves no bug. This reproduction is the only test the loop writes itself; broader strategy, coverage and non-bugfix suites go to `tester-agent` using `testing`.

Follow user routing for large work: `coder-agent` for non-trivial Go/TypeScript, `fixer-agent` for fully specified mechanical edits. Delegate claims are not evidence; run the gate yourself.

`jj diff --stat` must contain only scoped files, with exactly these exceptions:

- `docs/ux.md` when the phase touches its declared `ui_paths`, to record the screen/component contract.
- The adjacent test covering a scoped source file, never a new test package or second source file.

### 4. Verification gate

First renew: `../_shared/references/claim.sh renew <plan> <phase-id> "$token"`. Non-zero means the claim was lost: stop and report, do not gate another session's phase.

Every applicable item must produce real output:

1. **Clean before measuring.** Remove stale artifacts before counts/benchmarks (`go clean -cache` where relevant, remove stale `.pyc`, regenerate goldens for comparison only). Golden drift is never accepted by regeneration.
2. Run acceptance, then the full repo check: `make ci`, else `make fulltest`, else project test+lint. Quote actual output, never predicted runs. Full checks run once here, not inside red/green iteration; iterate with targeted tests and short `make test`.
3. For test-backed acceptance, deliberately break the fix, run the test and confirm red; restore and confirm green. Quote both. A green mutation is vacuous. `jj diff` must show no deliberate breakage left.
4. Any `SKIP` is red; name the test and reason.
5. Goldens must remain byte-identical. Drift: report and set `blocked`, never regenerate it away.
6. If the diff touches the migration directory, replay the whole chain onto an empty volume and restart the stack; quote successful output from both. Failure is a hard `blocked` stop, even if the full check/fresh build passed; never wave through a reordering.
7. Inspect `jj diff go.mod go.sum` or the ecosystem manifest. A dependency diff not named by phase scope is a hard `blocked` stop; report the added module. Run the promotion check below; it must print nothing.
8. Prefix every claim not backed by a command executed this turn `UNVERIFIED:`; never argue from untested assertions.
9. Run `../steering/references/verify-plan.sh` on the resolved plan. All `Refs` must resolve; deprecated/superseded ADR refs hard-stop. Resolve UX with `eval "$(../_shared/references/resolve-paths.sh)"`, never assume `docs/ux.md` (foreign repos use `.claude/project/ux.md`). If `$UX` exists and scope intersects its `ui_paths`, require `UX:<screen-id>` or `UX:system` and run `../steering/references/verify-ux.sh "$UX"`, exit 0. Absent `$UX` skips only this UX half.

Promotion check: with `go.mod`, run:

```bash
SELF=$(go list -m)
comm -13 \
  <(go mod edit -json | python3 -c 'import json,sys; d=json.load(sys.stdin); [print(r["Path"]) for r in (d.get("Require") or []) if not r.get("Indirect")]' | sort) \
  <(go list -deps -f '{{if .Module}}{{.Module.Path}}{{end}}' ./... | sort -u) \
  | grep -v "^${SELF}$"
```

No `go.mod`: skip this command, manually check the ecosystem's direct-dependency list or mark `UNVERIFIED:`. An errored command printing nothing is not a pass. Never directly import a package present only transitively. Functional depth is bounded to 1; structural dependency depth is unbounded. Apply the same ownership rule to support code: a package supporting another must not be imported by a third; enforce with `internal/<owner>/internal/` placement.

**Done when:** acceptance and full check exited 0 with quoted output; mutation red/restored green are quoted where applicable; no skips or golden drift; migration replay/restart succeeded where applicable; dependency changes are planned and promotion output empty; refs/UX gates pass; diff contains only intended changes. Failures follow the persistent retry/hard-stop rules above.

### 5. Commit

Load and apply `commit` in full: it owns jj mechanics, message composition, `--stdin` heredocs, hook-failure stop and tracked changelog obligations. One phase is one atomic commit; split independently committable changes per that skill rather than bundling.

Finish with `jj new`, never merely describe. Done only when `commit`'s checks pass, no publishing occurred, and `jj log -r @ --no-graph -T description` is empty with a fresh empty working change.

### 6. Advance state and stop

Before any closing plan write:

```sh
../_shared/references/claim.sh verify <plan> <phase-id> "$token"
```

Non-zero: stop and report. The existing commit is safe, but the plan entry now belongs to another claimant; do not close it.

On success set `verified`, clear `Claimed-by` and `Attempts`, append:

```text
<phase-id> | verified | <commit change-id> | <one-line what> | <refs>
```

Carry phase refs and a real change-id. Include tracked `PLAN.md` updates in the phase commit; private plans are written only to disk after that commit exists. Leave the fresh working change required by step 5.

Stop and report the closed phase, evidence, next `todo`, and any newly recorded phases. Disk state must suffice to resume without conversation history.

## Chaining (`--chain N`)

Only when explicitly passed, load `references/chaining.md`. All core steps and gates still run per phase.

## Bootstrap (no plan file yet)

Use steering's `/10x:plan init` for the context scaffold, conditional UX contract and empty plan; stop for approval. Loop executes phases, not their source documents.

If steering is unavailable, mine existing plans, `.claude/project/`, `docs/adr/`, TODOs, failing tests and conformance findings; invent no roadmap. Write `.claude/plan/<slug>.md` unless an explicit path was given; tracked `PLAN.md` only on user request. Stop for approval, never implement in the creation turn. Commit a tracked plan alone; private plans remain uncommitted.

Use the loaded plan format for stable ids, goals, scope, `New deps` with product function (default `none`), `Refs`, runnable acceptance, dependencies, status and bugfix `Repro`. A dependency must answer which required product function disappears without it: "only stops compiling" is structural, stays with its owner; "none" is removed. Rewrite or split criteria until a command decides them.

Done only with no `<...>`/`{{...}}` placeholders, every required field filled (`none` is legal), runnable acceptance per phase, `verify-plan.sh` exit 0, path reported and tracking rules obeyed.

## PLAN.md template

Before creating a plan, load the canonical Shape, Fields, Phase ids, `Refs`, Bugfix phases and Log sections of `../_shared/references/plan-format.md`; copy that format, fill placeholders, use the five-column Log above. `Refs: none` warns rather than blocks; do not invent requirements for traceability.

## MUST NOT

Do not bypass Invariants or any point-of-action stop above. In particular, never publish, silently expand scope/dependencies, accept unevidenced green, replace drifted goldens, retry a third time on the same diagnosis, or execute an unapproved phase/acceptance criterion.
