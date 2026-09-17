---
name: 10x-doc
description: 'Self-documentation for the 10x plugin: what commands exist, what the concepts mean, which files the system manages, and where the current project stands. Use when asked what 10x can do, what a plugin concept means, which command fits a situation, or for a snapshot of a project running under 10x. Not for a graded review of code quality: use the built-in /code-review. Not for auditing a repo against the engineering standard: that is 10x-conform.'
---

# 10x Doc

A plugin nobody can enumerate is a plugin nobody uses past the three commands
they happen to remember. This skill answers two questions in one pass: what does
this system offer, and where does this project stand inside it.

The catalogue is **derived, never recited**. `plugins/10x/README.md` is the
cautionary tale: hand-maintained, it lists three commands out of eight and
contradicts `/10x:evaluate` on which third model it calls. Nothing fails when a
prose list drifts, so it drifts. Read the files instead.

## Output

Two sections, always in this order.

### Section 1: the reference

Static, identical in any directory. Built from `references/inventory.sh`, which
reads the frontmatter of every command, skill and agent on disk.

- **Commands**, grouped by use: steering (`plan`), execution (`loop`), conformance (`check_conform`, `make_conform`, `propose_probe`), consultation (`tellme`, `evaluate`), session (`handoff`, `doc`). Each with its argument hint and one line.
- **Skills**, with the command that exposes them where one does. Most have none: they load by description, which is worth stating explicitly since it is the part users do not expect.
- **Agents**, with what each is for.
- **Concepts**, from `references/glossary.md`. Do not paraphrase it: quote the definitions that matter for the question asked, or all of them when the request is open.
- **Files**, the artifacts the system manages in a target project, with owner and tracked status.
- **The cycle**: `plan init` to scaffold, `plan add` to write a phase, `loop` to execute one, `plan check` to audit, `plan done` to close. `handoff` at any interruption.

When the user asks about one thing (a command, a concept), answer that and skip
the rest. The full dump is for an open request.

### Section 2: this project

Dynamic. Skipped in one line when there is nothing to report, which is the
normal case in the plugin repo itself or anywhere without `.claude/`.

Report only what a command produced this turn:

| What | How |
|---|---|
| Ownership and profile | `../10x-plan/references/ownership.sh`, `10x-profile:` in `CLAUDE.md` |
| Which artifacts exist | `test -f` on the file set below |
| Plan resolution, phases by status | `../10x-plan/references/verify-plan.sh` and the plan itself |
| Next phase the loop would take | first `todo` whose `Depends on` are all `verified` |
| Contract and decision conformance | `verify-ux.sh`, `verify-adr.sh` |
| Standard drift | `../10x-conform/references/conform.sh`, when asked |

Quote what the scripts print. Never restate a status the conversation happens to
remember: this section exists because memory of a repo is exactly what goes
stale.

**Do not run `conform.sh` by default.** It is slower than the rest and answers a
different question. Run it when the request mentions the standard, drift, or
conformance.

## Answering a question rather than dumping

Most invocations are a question, not a request for the catalogue. Route it:

- "what can 10x do", "list the commands" gives Section 1 in full, Section 2 in one line.
- "where am I", "what is next" gives Section 2, and only the part of Section 1 that names the command to run next.
- "what is a phase", "what does `Refs:` mean" gives the glossary entry and the skill that owns it. Nothing else.
- "which command for X" names one command and why, not a list to choose from.

## Done when

- Every command, skill and agent named came out of `inventory.sh` this turn, never from memory or from `README.md`.
- Every concept definition came from `references/glossary.md`.
- Section 2 either quotes a command run this turn, or says in one line that there is no project here.
- Nothing was modified. This skill is read-only.

## MUST NOT

- Recite a command list from memory or from a README. Both drift; the frontmatter cannot.
- Claim a skill exists without a `SKILL.md` on disk, or a command without a file in `commands/`.
- Report a project status that no command produced this turn.
- Modify any file, including the plugin's own documentation. Fixing a drifted README is a separate, explicit act.
- Duplicate what a skill already documents. Point at the skill; the definition lives there.
