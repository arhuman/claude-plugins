---
name: manual
description: 'Read-only 10x self-documentation: capabilities, commands, concepts, managed files, and current project status. Not for graded code review (built-in /code-review) or engineering-standard audits (conform).'
---

# 10x manual

## Output

Use reference then project sections, narrowed to the question. Derive inventory from `references/inventory.sh` this turn, never memory or README prose. Quote relevant [glossary](references/glossary.md) definitions verbatim; quote all for an open request. Point to owner skills for usage, do not duplicate their documentation.

### Section 1: the reference

Directory-independent inventory:
- Commands grouped by steering, execution, conformance, consultation, session, each with argument hint and one-line purpose.
- Skills and exposing commands where present; explain that most load by description.
- Agents and purposes; concepts; managed project files with owner/tracked status.
- Cycle: `plan init`, `plan add`, `loop`, `plan check`, `plan done`; `handoff` at interruptions. Confirm names against current inventory before presenting.

### Section 2: this project

Quote only command output from this turn. If no project/nothing to report (normally no `.claude/`), say so in one line.

| Evidence | Source |
|---|---|
| Ownership/profile | `../steering/references/ownership.sh`; `10x-profile:` in CLAUDE.md |
| Artifacts present | `test -f` on managed files from reference section |
| Resolved plan/statuses | `../steering/references/verify-plan.sh` and plan |
| Next phase | first `todo` with every dependency `verified` |
| Contract/decision conformance | steering `verify-ux.sh`, `verify-adr.sh` |
| Standard drift | `../conform/references/conform.sh` only when standard/drift/conformance requested |

## Answering a question rather than dumping

| Request | Answer |
|---|---|
| Capabilities/command list | full reference; project in one line |
| Where am I/next | project evidence; only relevant next command from reference |
| One command/concept | only that item, definition and owner |
| Command for X | one command and why |

## Done when

Every named command/skill/agent came from this turn's inventory; confirm command files and SKILL.md exist. Definitions came from glossary; status came from fresh commands or an explicit no-project line. Nothing modified, including plugin docs; fixing documentation requires a separate explicit request.
