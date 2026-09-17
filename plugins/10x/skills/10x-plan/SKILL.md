---
name: 10x-plan
description: 'Steering documentation for agentic development: initialize the project scaffold (PRD, tech notes, ADR home, UX contract), write and audit the execution plan that 10x-loop runs, and route a newly stated rule to the file that should hold it. Use to bootstrap a project chantier, add or promote a phase, report plan status, record a cross-cutting rule, or check the whole set for inconsistency. Not for executing a phase: that is 10x-loop. Not for grading code quality: use the built-in /code-review.'
---

# 10x Plan

Four artifacts already existed and none of them talked to each other: a scaffold
that creates empty files and decides nothing, a grilling session that ends at
the decision, a loop that executes a flat plan, and a design skill that defends
CSS with machinery and intent with nothing. The gap between them is where the
work actually goes wrong: a phase can go green while violating an accepted ADR,
because nothing ties a phase to what justifies it.

This skill owns the steering documents and the plan. It never executes a phase.

## The document set

Five files, three of which already existed. Two are private working context,
three are contracts the code must honour.

| File | Holds | Tracked |
|---|---|---|
| `.claude/project/prd.md` | Why. Requirements table with stable `R1..Rn` ids | no |
| `.claude/project/tech.md` | Stack, conventions, reversible technical notes | no |
| `.claude/plan/<slug>.md` | Execution: phases, statuses, log | no |
| `docs/adr/NNNN-slug.md` | Decisions that are hard to reverse | **yes** |
| `docs/ux.md` | Interface contract: screens, components, state rules | **yes** |
| `CONTEXT.md` | Domain glossary, and nothing else (owned by `grill-with-docs`) | **yes** |

The three tracked paths hold only on a repo that is ours; see Ownership below.

The split is not cosmetic. What lives under `.claude/` is the author's own
working context: intentions, sequencing, rhythm. It is nobody else's business
and it changes too fast to survive review. What lives under `docs/` is a
contract someone else must honour, so it has to be readable in a diff, and it is
the only part a CI job can see at all.

Two consequences follow, and they are load-bearing:

- `verify-ux.sh` reads only tracked files, so it **runs in CI**.
- `verify-plan.sh` reads the plan and the PRD, so it is **local only**, and it exits 0 when they are absent. A missing plan is a private context that was never shared, not a violation.

**Never create a second requirements document.** The Requirements table in
`prd.md` is the only place a requirement id exists. A second one drifts from the
first within a month and nobody knows which arbitrates.

## Ownership: whose repo is this

Three of these files are tracked, so on a fork or a third-party checkout they
would land in a pull request, proposing methodology files the maintainer never
asked for inside a change that was supposed to fix a bug. That is not clutter,
it is a social mistake, and no amount of usefulness excuses it.

So before any write, resolve ownership with `references/ownership.sh`, which
prints `owned` or `foreign`. It reads, first hit wins: an explicit
`PLAN_OWNERSHIP` override; a `10x-profile:` key in `CLAUDE.md` or `AGENTS.md`
(the repo already runs this methodology, so its documents belong in it); whether
`gh` reports the repo as a fork; the presence of governance somebody else wrote
(`CODE_OF_CONDUCT.md`, an issue-template set). With no signal at all, a repo on
your disk is yours.

On a `foreign` repo, nothing is written into the tracked tree. Everything moves
under `.claude/`, which is gitignored and therefore invisible in a diff:

| Artifact | `owned` | `foreign` |
|---|---|---|
| `.claude/project/`, `.claude/plan/` | same | same |
| UX contract | `docs/ux.md` | `.claude/project/ux.md` |
| Decisions | `docs/adr/NNNN-*.md` | `.claude/project/decisions/NNNN-*.md` |
| `CONTRIBUTING.md`, `SECURITY.md` | created if missing | **never** |
| `CONTEXT.md` | as `grill-with-docs` decides | `.claude/project/context.md` |

`verify-ux.sh` already takes a path argument, so it works on the relocated file
with no change.

State the verdict and its reason before writing, every time. And say what it
costs: on a `foreign` repo the UX contract is no longer diffable in review, so
it stops being a shared contract and becomes private notes. That function was
never yours to claim on someone else's project.

An `owned` verdict on a repo that is not yours is the expensive error, so when
the signals disagree, ask rather than assume.

## Formats

Both are shared contracts, held once and referenced, never copied:

- Plan and phase shape: `../_shared/references/plan-format.md`
- UX contract shape: `../_shared/references/ux-contract.md`
- ADR shape: `../grill-with-docs/ADR-FORMAT.md` (ADR Contract v1)

Read the relevant one before writing; do not re-derive a format from an example.

## init

Bootstraps the chain. Creates what is missing, fills nothing.

0. **Resolve ownership first** (see above) and state the verdict. Everything below assumes `owned`; on `foreign`, the tracked artifacts move under `.claude/` and the root governance files are skipped entirely.
1. Create the scaffold: `.claude/project/{prd.md,tech.md}`, `.claude/project/issues/`, `.claude/project/archives/`, `.claude/CHANGELOG.md`, and, **on an `owned` repo only**, `CONTRIBUTING.md` / `SECURITY.md` at the root when absent. Templates in `references/`. `docs/adr/` is created lazily, on the first ADR, never seeded empty.
2. Normalize the Requirements table to `R<n>` ids if it uses bare numbers, **with explicit agreement**. A bare `3` is not greppable; `R3` is. This is what makes `Refs:` resolvable at all.
3. Create `docs/ux.md` from `references/ux.md` **if the repo serves an interface**. That is a test, not an opinion: the repo holds at least one `.html`, `.templ`, `.tmpl` or `.css` file outside dependency directories. Write the answer into `ui_paths` so the question is settled once and never guessed again. If the test is ambiguous, ask.
4. Create `.claude/plan/<slug>.md` with its title and status legend, **with no phase**.
5. Notify mnemos (see below).

**Invent nothing.** No requirement, no phase, no screen. Files come out empty or
normalized, and stay that way until the user or the code provides real content.
An `init` that fills the PRD by itself is the first step toward a PRD nobody
reads, and that rule is inherited verbatim from the scaffold this verb absorbs.

**Done when:** the ownership verdict and its reason were stated; the plan exists
and carries its legend; the UX contract exists at the path ownership dictates, or
its absence is justified by "no UI detected"; `git status --porcelain` shows no
`M` on `docs/` (the run created, it overwrote nothing), and on a `foreign` repo
shows no new tracked path at all; the mnemos notification outcome is reported.

## status

Read only, zero writes.

Resolve the plan with **exactly the same cascade as the loop**, then report:
phases by status including the `backlog` population, the phase the loop would
actually take next, `blocked` phases with their reason, phases whose dependency
sits in `backlog`, and `must` requirements with no phase serving them.

**The next-phase rule has one implementation, shared with the loop.** Two
implementations of one rule drift, and a `status` that announces P3 while the
loop takes P4 is worse than no `status` at all: it destroys trust in everything
else. The rule is deliberately simple enough to hold identically in both places:
the first `todo` in file order whose `Depends on` are all `verified`.

**Done when:** the resolved plan path is stated; no file was modified; every
number comes from a file, never from the conversation.

## add

Adds **one** phase, per `plan-format.md`.

| Invocation | Writes |
|---|---|
| `add "..."` | appended at the end, status `todo` |
| `add --urgent "..."` | inserted after the last `verified` phase, before the first `todo` |
| `add --backlog "..."` | appended at the end, status `backlog` |
| `add --promote <id>` | `backlog` to `todo` |

`--urgent` never inserts at line 1: a phase placed before closed history makes
the log contradict the file. Ids stop being monotonic as a result, which is
harmless.

**The id is allocated repo-wide, never per file** (see `plan-format.md`, Phase
ids): max+1 over every phase id in `.claude/plan/*.md` **and**
`.claude/project/archives/`. Archived plans consumed their numbers; reusing one
would collide with the commit messages and reserves that cite it. A new plan's
first phase therefore rarely starts at `P1`, which is expected: the id
identifies, position ranks.

The real work of this verb is forcing the obligatory fields: a closed `Scope:`,
a genuinely runnable `Accept:`, a resolved `Refs:`. If the requirement does not
exist in the PRD, **propose** an `R<n>` row and ask; never add one silently.

**Default validation: the `Accept:` must be decidable.** Run it once; what is
required is a usable verdict (an exit code, not a command-not-found). Not that
it fails: a refactoring phase has green tests as its criterion, and demanding
red there only teaches people to write fake criteria.

**Bugfix validation is inverted.** `Repro:` present and non-empty; `Scope:`
including a test file; and an `Accept:` naming a test that does not yet do its
job. Two admissible forms: the test does not exist (`grep -r "func TestX"`
returns nothing), or it exists and passes despite the bug, which is the common
case and means it exercises the wrong path. The phase must say which, because
the work is not the same: write a test, or fix a test that lies.

This verb is also where the loop records a defect found outside its scope.

**Done when:** the written phase carries no placeholder; its id collides with
no phase in `.claude/plan/` or the archives; its `Refs:` resolve; the
validation matching its type ran and its output is quoted; no other phase was
touched.

## rule

`/10x:plan rule "every data list exposes a sort on name"`

The write path for the contract files, where `add` is the write path for the
plan. Without it, `docs/ux.md` is filled at `init` and dies: a cross-cutting
rule stated six weeks later has no way in, since `init` does not know it, `add`
creates phases, and the loop only writes statuses.

This is a **short session**, not a write. It borrows the method of
`grill-with-docs` (one question at a time, only those that change the outcome,
depth calibrated to the density of the input) without invoking that skill: you
do not interrogate a decision already made, you file it.

Five steps, in this order, because each can make the next moot:

1. **Conflict.** Does this contradict a rule already written? Highest-value step, because the user does not remember everything the files hold. Same move `grill-with-docs` makes against the glossary: "the contract already says lists sort by creation date, do you replace it or do both stand?"
2. **Ambiguity.** Does "every list" mean every `<ul>` or every paginated data list? Does "sortable" mean server-side ordering or client-side reordering? The destination **follows** from this: server-side sorting is pagination, so `tech.md` or an ADR; client reordering is purely UX.
3. **Destination**, only if still open after step 2. Proposed with its criterion, never as a neutral menu.
4. **Rewording.** A rule is written as a verifiable imperative. "Lists should be sortable" becomes "Every data list exposes a sort on name": a conditional is not a rule, and no check can act on one.
5. **Conformance debt**, once the line is written.

### Routing

| Destination | Criterion | Example |
|---|---|---|
| `docs/ux.md`, `## Invariants` | keeps features consistent with each other | "create and edit render the same form partial" |
| `docs/ux.md`, other sections | constrains what the user sees or does | "every data list exposes a sort on name" |
| `docs/adr/NNNN-*.md` | passes ADR Contract v1's three-part gate: hard to reverse, surprising without context, a real trade-off | "pagination is cursor-based, not offset" |
| `.claude/project/tech.md` | technical convention, reversible, no notable trade-off | "handlers return typed errors" |
| `CONTEXT.md` | it is a domain **term**, not a constraint | "we say statement, not invoice" |

The ambiguous case is real and frequent: cursor pagination is an ADR if the
choice durably excludes offset, a technical note if it is just house style. Do
not guess: the act is rare, one more question costs nothing, and getting it
wrong is expensive (a bogus ADR pollutes an immutable series; a structural
decision buried in `tech.md` is invisible).

The fourth destination is the only one where `grill-with-docs` remains the right
tool: defining a term needs interrogation, and that is its job.

**Zero questions when nothing is at stake.** This is the indispensable
counterpart to being interactive: with no conflict detected, an obvious
destination and an already-imperative wording, write and report. Five questions
to file "delete buttons are red" is the moment the verb stops being used. The
stop criterion is `grill-with-docs`'s own: stop when the remaining gaps are
explicit assumptions, not when the questions run out.

### rule in bulk: `--from`

`/10x:plan rule --from-code`
`/10x:plan rule --from <path-or-url>`

Two moments defeat the one-rule-at-a-time form, and they are the same problem at
different ends of a project: filling an empty contract on a repo that already
has ten screens, and absorbing a design handoff that arrives mid-project with
thirty rules at once. Both read a source and **propose** a contract; the user
accepts, edits or rejects each line. Neither ever writes silently.

The source decides what the mode compares against, and that changes everything
about what comes out.

**`--from-code` reads the repository, and the code is the authority.** It says
what the interface *is* today. Output is mostly discovery.

- **Screens and Components tables.** Purely mechanical: templates on disk, `blocks/NNN-*.css` on disk. The `used by` column follows from grepping block names in templates. Only the two intent columns need the user.
- **Invariants, from repetition.** A pattern present in every screen is already a rule, written in code and nowhere else. Three chips for a low-cardinality field across four templates, one shared form partial for create and edit: those hold today and would break silently tomorrow. Propose each with the files that evidence it.
- **State rules, from the templates.** How empty, error and loading are rendered today. If screens disagree, that is the finding: say which ones, and ask which is right.

**`--from <source>` reads a handoff, and the code is not the authority.** A
handoff describes what the interface *should become*, so it contradicts both the
code and the contract on purpose. Output is mostly conflict, and conflict is the
useful part.

- **Conflicts first, and they are the point.** For every rule the handoff implies, check it against what `docs/ux.md` already says. "The contract says mutations confirm with a toast, never a blocking modal (since 2026-08-01); the handoff puts editing in a side panel. Replace, or do both stand?" Each conflict is resolved before anything is written; an unresolved one is not a rule, it is a repo with two generations of screens and no record of which is current.
- **Then the additions.** New screens, new components, new patterns that contradict nothing.
- **Conformance debt, per replaced rule.** Screens predating the new `since` marker become `backlog` phases, proposed with explicit agreement and never generated in bulk. This is what makes a mid-project style change survivable rather than a slow fork.

**Never import token values.** A handoff arrives with colours and spacings;
`docs/ux.md` forbids literal values and `verify-ux.sh` enforces it. Values go to
`tokens.css`, which is their single source of truth. The contract records that a
family exists, never what it is worth. A handoff that introduces a genuinely new
family is worth one line under `Token families`, pointing at the stylesheet.

**Offer the ADR for a direction change.** A new visual direction mid-project
passes ADR Contract v1's three-part gate: hard to reverse (migrated screens do
not come back), surprising without context (why two styles coexist in the repo),
and the result of a real trade-off (a transition period was accepted). Propose
it once, before the rules, so the switch is dated and the coexistence is
deliberate. Do not offer one per rule the handoff implies.

**Never invent a `Direction`.** If the visual direction came from a handoff, the
user states it or the section stays `TODO`: no table depends on it. And never
propose an invariant that some screen contradicts without saying so. "Four
templates do this, one does not" is the useful form, and the exception is often
the bug.

**Done when:** every proposed line was accepted, edited or rejected explicitly;
every conflict with an existing rule was resolved or recorded as deliberate
coexistence; accepted lines carry today's date as their `since` marker; no
literal value entered the contract; `verify-ux.sh` exits 0 on the written file.

### Conformance debt

A new rule leaves already-shipped screens non-conforming. The rule applies
immediately to new work; the non-conforming past becomes `backlog` phases,
proposed with explicit agreement and never generated in bulk.

The `<!-- since YYYY-MM-DD -->` marker is what makes this computable: it
separates "this screen breaks the rule" from "this screen predates the rule".
Without it the warning fires on everything forever and stops being read.

**Done when:** the rule is a verifiable imperative; it carries its `since`
marker; its destination was stated with the criterion that selected it;
conflicts were resolved or recorded as deliberate coexistence; the debt was
computed and proposed.

## done

Closes a finished chantier. The plan is the only artifact of this system that
dies, and until now nothing killed it: a completed plan stayed in place, `check`
kept reading it, and the mnemos pointer kept naming a dead chantier.

1. **Refuse an unfinished plan.** Every phase must be `verified`. Otherwise list what remains, by status, and stop without touching anything. A `blocked` phase is not a reason to close: it is the reason not to.
2. **Write the closing summary** at the top of the plan: phases closed with their change-ids, requirements served (from the `Refs:` lines), ADRs produced during the chantier.
3. **Archive** the file to `.claude/project/archives/`, keeping its name.
4. **Retire the mnemos pointer**, under the same three conditions as the notification below. Silent when mnemos is absent.
5. **Report the residue.** `backlog` phases were never promoted: they are what the chantier decided not to do, and they die with the file unless they move to the next plan. Name them; never carry them over silently.

**Done when:** no phase was left unclosed, or the command stopped and said which;
the archived path was stated; the mnemos pointer no longer names the archived
file; the `backlog` residue was listed for the user to decide on.

## check

Diagnosis only. It repairs nothing: repair is `add`, `rule`, or a manual edit.

**Mechanical layer**, `references/verify-plan.sh` and `references/verify-ux.sh`.
Run both, quote their output verbatim. Blocking: an unresolvable `Refs:` id, a
reference to a `deprecated` or `superseded` ADR, a UI phase with no `UX:` ref, a
screen or block missing from the contract or the reverse, a literal value in
`docs/ux.md`, a dependency cycle or a dependency on a nonexistent phase, a
status outside the enum. Also relays `verify-adr.sh` for ADR conformance.

Warnings, never blocking: `Refs: none`, a `must` requirement with no phase, a
`todo` phase whose dependency sits in `backlog`, a stale `ui_path`, a phase id
duplicated in another plan or an archive (the script cannot tell a
grandfathered id from a misallocated one; enforcement lives in `add`).

The backlog dependency deserves its line: it produces a silent deadlock. If P2
(`todo`) depends on P1 promoted to `backlog`, the loop skips P2 every turn
without ever saying why, and the plan looks like it is progressing while it is
dead. It is the only case where inaction is indistinguishable from normality.

**Judgment layer**, warnings only, each prefixed `UNVERIFIED:`:

- a phase whose scope contradicts an accepted ADR;
- two screens claiming the same dominant action, or a tension written as a feature rather than as a relief;
- a requirement whose phases are all `verified` but whose success criteria are not measured.

**Done when:** both scripts ran and their output is quoted; every judgment item
is prefixed `UNVERIFIED:`; no file was modified.

## mnemos notification

Goal: mnemos knows where the source of truth is, without ever holding it.

When `init` creates a plan, or when a plan disappears, write one note through
`mnemos.remember` at `decisions/active-plan.md`: the plan path, the project, and
the explicit statement that this file arbitrates the phases and that tasks must
not be duplicated on the mnemos side. One note per project, rewritten in place,
never accumulated.

**A pointer, never content.** Copying phases into mnemos would violate its own
rule (do not capture what the repo already holds, cite it) and create a second
truth. This also resolves a real conflict: the mnemos skill silently creates a
task on every work request, which would shadow the plan. The note tells it not
to, on this repo.

**Degradation.** Conditional on three tests, in order: are the mnemos MCP tools
available, does the project have a mnemos workspace, is writing allowed. If any
fails, write nothing and continue. Report it only when it succeeded, or when it
was attempted and failed. **The absent case is silent**: a system that nags
about an optional tool being missing is a system people uninstall.

No command depends on mnemos to complete. That is the direct counterpart of the
rule that the plan file is the single source of truth for execution.

## MUST NOT

- Execute a phase. That is `10x-loop`, and the separation is what keeps this skill auditable.
- Create a second requirements document, or a decisions file parallel to `docs/adr/`. Two numbering series always collide.
- Persist a quality score. A script can only check that a score is filled, never that it is right, so the gate ends up satisfied by a constant.
- Add a requirement, a phase, a screen or a rule the user did not approve.
- Write a plan phase whose `Accept:` no command can decide.
- Fill the PRD by inference at `init`.
- Block on anything a script cannot decide. Judgment produces `UNVERIFIED:` warnings, never an exit code.
- Repair inside `check`.
- Write a tracked file into a repo that is not ours. On `foreign`, the tracked artifacts move under `.claude/` and the root governance files are never created.
- Push, tag, or release. Those are the user's manual acts, here as in the loop.
