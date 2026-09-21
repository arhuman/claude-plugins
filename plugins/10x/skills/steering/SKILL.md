---
name: steering
description: 'Own steering documents and the execution plan: initialize PRD/tech/ADR/UX scaffolds, add or promote phases, report status, route rules, and check consistency. Use to bootstrap a project chantier or maintain its contracts. Never executes phases (use loop) or grades code quality (use built-in /code-review).'
---

# 10x Plan

Own documents and plans; never execute phases.

## The document set

| Artifact | Holds | Tracking on owned repos |
|---|---|---|
| `.claude/project/prd.md` | Requirements, unique stable `R1..Rn` ids | private |
| `.claude/project/tech.md` | Stack, conventions, reversible notes | private |
| `.claude/plan/<slug>.md` | Phases, statuses, log | private |
| `docs/adr/NNNN-slug.md` | Hard-to-reverse decisions | tracked |
| `docs/ux.md` | Screens, components, state rules | tracked |
| `CONTEXT.md` | Domain glossary only | tracked |

The PRD Requirements table is the sole requirement-id authority. Never create a parallel requirements document or decision-numbering series. `verify-ux.sh` checks tracked contracts in CI on owned repos; `verify-plan.sh` reads private plan/PRD, is local-only, and exits 0 when absent.

## Ownership: whose repo is this

Before every write, run `references/ownership.sh`; state `owned`/`foreign` and reason. First signal wins: explicit `PLAN_OWNERSHIP`, `10x-profile:` in CLAUDE.md/AGENTS.md, `gh` fork status, existing foreign governance (CODE_OF_CONDUCT.md, issue templates). No signal defaults to owned. Conflicting signals: ask, never assume owned.

| Artifact | owned | foreign |
|---|---|---|
| `.claude/project/`, `.claude/plan/` | same | same |
| UX | `docs/ux.md` | `.claude/project/ux.md` |
| ADRs | `docs/adr/NNNN-*.md` | `.claude/project/decisions/NNNN-*.md` |
| CONTRIBUTING.md, SECURITY.md | create at root if missing | never create |
| Glossary | root `CONTEXT.md` | `.claude/project/context.md` |

On foreign repos write no tracked artifact; all methodology context stays gitignored under `.claude/`. Explain that private UX notes lose shared, review-diffable contract status. Pass the resolved UX path to `verify-ux.sh`. Paths below assume owned; apply this table throughout.

## Formats

Before writing the relevant artifact, load its canonical contract, never infer from examples:

- Plan: `../_shared/references/plan-format.md`.
- UX: `../_shared/references/ux-contract.md`.
- ADR: `references/ADR-FORMAT.md` (Contract v1).
- Glossary: `references/CONTEXT-FORMAT.md`.

## init

Create missing scaffolds only; invent no requirements, phases or screens. Existing files are not overwritten and PRD content is not inferred.

1. Resolve/report ownership before writing.
2. Create `.claude/project/{prd.md,tech.md}`, `.claude/project/issues/`, `.claude/project/archives/`, `.claude/CHANGELOG.md`; owned only: absent root CONTRIBUTING.md/SECURITY.md. Load corresponding `references/{prd,tech,changelog,contributing,security}.md` templates when creating each. Create the ADR directory lazily with the first ADR, using `references/adr.md`, never empty.
3. Normalize bare Requirements ids to `R<n>` only with explicit agreement.
4. Detect UI: at least one `.html`, `.templ`, `.tmpl` or `.css` outside dependencies. If present, create the resolved UX contract from `references/ux.md`, recording the surface in `ui_paths`; ask if ambiguous. Otherwise report "no UI detected".
5. Create `.claude/plan/<slug>.md` with title and status legend, no phases. Notify mnemos as below. Stop for approval.

Done: ownership/reason stated, plan/legend and conditional UX exist, `git status --porcelain` shows no `M` on `docs/` and no new tracked path on foreign repos; report mnemos outcome only under its reporting rules.

## status

Read-only. Load plan-format's resolution/eligibility rules, identical to loop: explicit path, else `.claude/plan/*.md`, else `PLAN.md`; multiple private `todo` plans require asking. State resolved path. Report file-derived counts by status including backlog, first eligible `todo` in file order (all dependencies verified), blocked reasons, backlog dependencies, and `must` requirements with no serving phase. No conversation-derived counts or writes.

## add

Load plan-format and write exactly one phase:

| Invocation | Placement/status |
|---|---|
| `add "..."` | append, `todo` |
| `add --urgent "..."` | after last `verified`, before first `todo`, never before closed history |
| `add --backlog "..."` | append, `backlog` |
| `add --promote <id>` | existing `backlog` becomes `todo` |

Allocate new ids repo-wide: max+1 across `.claude/plan/*.md` and `.claude/project/archives/`, never per file. Id identifies; position ranks. Do not renumber old ids.

Require closed `Scope`, decidable `Accept`, resolved `Refs` and all canonical fields, no placeholders. Missing PRD requirement: propose an `R<n>` row and ask, never add silently. This verb also records loop discoveries outside its scope.

- Default validation: run acceptance once and quote output. Require a usable exit verdict, not command-not-found; green is legal for refactoring.
- Bugfix validation instead: non-empty `Repro`, test file in scope, `Accept` naming a test not yet doing its job. Establish and state which case: absent test (search returns none), or existing test passing despite the bug (wrong path). The implementation loop must later prove a real assertion failure.

Done: one phase affected, collision-free id, no placeholders, refs resolve, type-appropriate validation output quoted.

## rule

`/10x:plan rule "every data list exposes a sort on name"`

Short session, one outcome-changing question at a time, depth matching input. In order: (1) check conflicts with rules/glossary, (2) resolve ambiguity, (3) propose destination with criterion if still unclear, (4) write a verifiable imperative, (5) compute conformance debt. Do not interrogate a settled decision. With no conflict, obvious destination and imperative wording, write/report with zero questions; stop when remaining gaps are explicit assumptions.

### Routing

| Destination | Criterion |
|---|---|
| UX `## Invariants` | consistency across features |
| UX other sections | what users see/do |
| ADR | hard to reverse, surprising without context, real trade-off: all three |
| tech.md | reversible technical convention, no notable trade-off |
| CONTEXT.md | domain term, not constraint |

Server-side sorting/pagination is technical or architectural; client-side reordering is UX. Ask if permanence/trade-off is unclear (e.g. cursor pagination as durable decision versus house style). Domain terms require `grill-me` and the loaded CONTEXT format.

### rule in bulk: `--from`

`/10x:plan rule --from-code` or `/10x:plan rule --from <path-or-url>` proposes lines for explicit accept/edit/reject; never silently imports.

- **From code:** repository is authority for what exists. Discover screen templates and `blocks/NNN-*.css`; derive `used by` from template references; ask for the two intent columns. Propose repeated invariants with evidence files, naming every contradicting screen. Derive empty/error/loading state rules from templates; report disagreements and ask which governs.
- **From handoff:** source describes intended future, so code is not authority. Resolve conflicts with the current UX contract first, before writing; deliberate coexistence must be recorded. Then propose non-conflicting screens/components/patterns. Compute debt per replaced rule.
- Never import literal token values into UX. Values belong in `tokens.css`; a genuinely new family gets a contract line pointing there.
- For a mid-project visual direction change, offer one ADR before the rules: costly reversal, surprising coexistence, accepted transition trade-off. Never one ADR per rule.
- Never invent Direction: user states handoff direction or it stays TODO; tables do not depend on it.

Done: each line explicitly accepted/edited/rejected; conflicts resolved or deliberate coexistence recorded; accepted rules carry today's `since`; no literal values; `verify-ux.sh` exits 0 on the resolved file.

### Conformance debt

Rules apply immediately to new work. Date each `<!-- since YYYY-MM-DD -->` to distinguish older screens from violations. Compute existing nonconformance and propose `backlog` phases with explicit agreement, never bulk-generate them.

Done: verifiable imperative, dated marker, destination and criterion stated, conflicts resolved/coexistence recorded, debt computed/proposed.

## done

1. Require every phase `verified`; otherwise list remaining phases by status and stop without writes, including blocked/backlog.
2. Add closing summary atop plan: closed phases/change-ids, served requirements from `Refs`, ADRs produced.
3. Archive to `.claude/project/archives/`, preserving filename.
4. Retire mnemos pointer under the conditions below; absent mnemos is silent.
5. Report backlog residue for the user to decide; never silently carry unpromoted work into the next plan.

Done: all closed or refusal names remaining phases; archive path reported, pointer no longer names archived file when integration applies, residue listed.

## check

Diagnosis only; no repairs or writes. Run `references/verify-plan.sh` and `references/verify-ux.sh` with resolved paths; quote outputs verbatim. ADR conformance is relayed through `verify-adr.sh`.

| Result | Cases |
|---|---|
| Blocking, mechanically decidable | unresolvable refs; deprecated/superseded ADR ref; missing UX ref on UI phase; missing screen/block contract row or missing corresponding file; literal UX value; dependency cycle/nonexistent dependency; invalid status |
| Warning only | `Refs: none`; unserved `must`; todo depending on backlog; stale `ui_path`; duplicate id across plans/archives (new-id enforcement is in add, never renumber grandfathered ids) |
| Judgment warning, prefix `UNVERIFIED:` | scope contradicting accepted ADR; screens sharing dominant action; tension stated as feature rather than relief; fully verified requirement with unmeasured success criteria |

Done: both script outputs quoted, all judgments labelled, no files modified. Repair belongs to `add`, `rule` or manual edits.

## mnemos notification

On plan creation/disappearance, maintain one note per project via `mnemos.remember` at `decisions/active-plan.md`, rewritten in place: path, project, and explicit authority that the plan arbitrates phases and tasks must not be duplicated in mnemos. Store a pointer only, never phase content; retire on archive.

Test in order: MCP tools available, project workspace exists, writing allowed. Any failure: write nothing and continue. Report success or attempted failure; absence is silent. No command depends on mnemos.

## MUST NOT

- Execute phases, publish (push/tag/release), or write unapproved requirements/phases/screens/rules.
- Duplicate requirement/decision authorities, infer PRD at init, or persist quality scores.
- Write undecidable acceptance, make judgment blocking, or repair during check.
- Write tracked methodology files on foreign repos, including root governance files.
