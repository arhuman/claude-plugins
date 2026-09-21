# Artifact registry

Every file a 10x component writes or reads in a target project outside that
project's own source tree, with its writer, its readers, its format spec, and
its lifecycle. A path pattern stated here is cited, never restated: a component
that needs the path points at this table, so two components cannot drift to
two different spellings of the same artifact.

## Table

| Path pattern | Writer | Reader | Format spec | Lifecycle |
|---|---|---|---|---|
| `.claude/plan/<slug>.md` or `PLAN.md` | steering, loop (bootstrap, status advance) | loop, steering, /handoff | `plan-format.md` | Durable; archived to `.claude/project/archives/` by `plan done` |
| `.claude/project/archives/<plan>.md` | steering (`done`) | steering (phase-id allocation), `verify-plan.sh` | frozen `plan-format.md` shape | Permanent archive |
| `<plan>.claimlock/` | _shared (`claim.sh`, called by loop) | `claim.sh` only | directory as mutex, `plan-format.md` | Transient, milliseconds; broken after 60s as a crash residue |
| `.claude/project/prd.md` | steering (`init`) | `verify-plan.sh` (R-refs), humans | `steering/references/prd.md` | Durable steering doc |
| `.claude/project/tech.md` | steering (`init`, `rule`) | humans, /tellme tier 1 | `steering/references/tech.md` | Durable steering doc |
| `docs/ux.md` (foreign repo: `.claude/project/ux.md`) | steering (`init`, `rule`), loop (new screen rows) | loop gate, /design_handoff, `verify-ux.sh` | `ux-contract.md` | Durable, tracked. Both spellings resolve through `resolve-paths.sh`; never hardcode either |
| `docs/adr/NNNN-<slug>.md` | steering (`rule`) | loop (Refs), `verify-adr.sh` | `../../steering/references/ADR-FORMAT.md` | Durable; superseded, never deleted |
| `CONTEXT.md` (foreign repo: `.claude/project/context.md`) | steering (`rule`) | steering (`rule`) | `../../steering/references/CONTEXT-FORMAT.md` | Durable domain glossary |
| `.claude/handoff.md` | /handoff (write mode) | /handoff (`--resume`) | inline in `commands/handoff.md` | Ephemeral, one per repo, rewritten in place, gitignored |
| `.claude/doc/conform-<repo>.md` | /check_conform, /make_conform, conform-agent (via `diagnose-steps.md`) | humans | `../../conform/references/conformance-report.md` | Snapshot, regenerated per run, never re-read |
| `.claude/doc/probe-proposal-<slug>.md` | /propose_probe | humans (approval gate) | `../../conform/references/probe-proposal.md` | Draft until approved into `standard.yml` |
| `.claude/doc/design-brief-<scope>.md` | /design_handoff (brief mode) | external generator, humans | `../../design-system/references/design-handoff.md` | One per brief, never re-read by the plugin |
| `.claude/doc/<task-resume>.md` (+ `-gemini`/`-openai`/`-deepseek` siblings) | /evaluate | humans | inline in `commands/evaluate.md` | One per question; slug per the collision rule below |
| `.claude/doc/test-report-<slug>.md` | testing, tester-agent | humans | `../../testing/references/test-reports.md` | Snapshot per test campaign |
| `<css-dir>/.audit-ui-baseline` | /audit_ui (`baseline`) | `audit-ui.sh` (ratchet) | `../../design-system/references/quality-guards.md` | Durable ratchet floor |
| `CLAUDE.md` / `AGENTS.md` stamp (`10x-standard:`, `10x-profile:`) | nobody automated (hand-written; see note) | `conform.sh`, `ownership.sh` | `../../conform/SKILL.md` repo-stamp section | Durable declaration |
| `CHANGELOG.md` `[Unreleased]` (tracked, repo root) | commit (feat/fix/perf) | release tooling | Keep a Changelog | Durable; promoted at release. Distinct from a private `.claude/CHANGELOG.md` working log |

## Slug and collision rule

A writer whose artifact has a fixed prefix in the table (`conform-<repo>`,
`probe-proposal-<slug>`, `design-brief-<scope>`, `test-report-<slug>`) always
uses it; a freeform slug (`<task-resume>`) is chosen once, stated back before
writing, and never reuses an existing file's slug for different content.

## Re-read contract

Most `.claude/doc/` artifacts are diagnostic snapshots: written once per run,
consumed by a human, and never re-read by any component. 10x deliberately
favors rediagnosis over stale-cache risk (a conform run re-runs the probes
rather than trusting last week's report). A non-empty Reader cell naming a
component or script is a real coupling: change those paths with care, and
update this table in the same commit.

## Known gap

No 10x component writes the `10x-standard:` / `10x-profile:` stamp; it is set
by hand (or by whoever scaffolds the repo) and only read by tooling. Stated
here so nobody hunts for a writer that does not exist.
