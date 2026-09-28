---
description: 'What 10x offers and where this project stands: the commands, the concepts, the files the system manages, plus the current plan, its phases, and what the verifiers say. Read-only: derives the catalogue from the plugin files rather than reciting a list.'
---

## Usage
`/10x:manual` alone prints the reference and a one-line project status.

`/10x:manual <question>` answers that question instead of dumping everything:

| Asked | Answered with |
|---|---|
| `/10x:manual` | full reference, project status in one line |
| `/10x:manual where am I` | project status, and the command to run next |
| `/10x:manual phase` (or any concept) | that glossary entry and the skill that owns it |
| `/10x:manual loop` (or any command) | what it does, its arguments, what it will not do |
| `/10x:manual how do I start a project` | the cycle, named commands in order |

## Context
- Request: $ARGUMENTS
- Full workflow: `manual` skill
- Catalogue, derived: `skills/manual/references/inventory.sh [--commands|--skills|--agents|--scripts]`
- Concepts: `skills/manual/references/glossary.md`
- Project status: `skills/steering/references/verify-plan.sh`, `verify-ux.sh`, `verify-adr.sh`, `ownership.sh`

## Workflow
1. Load the `manual` skill.
2. Run `inventory.sh` for anything naming a command, skill or agent. Never answer that from memory.
3. Read `glossary.md` for anything naming a concept.
4. For project status, run the verifiers and quote their output. Outside a project, say so in one line and stop there.
5. Answer the question asked. The full catalogue is for an open request.

## Constraints
- Read-only. Never modify a file, including the plugin's own README.
- Never name a command, skill or agent that `inventory.sh` did not print this turn.
- Never report a project status that no command produced this turn.
- Do not run `conform.sh` unless the request mentions the standard, drift, or conformance: it is slow and answers a different question.

## Examples

`/10x:manual`
Prints the commands grouped by use, the skills with the command that exposes them, the agents, the concepts, the managed files, and the cycle. Then one line on the current project.

`/10x:manual where am I`
Resolves the plan, counts the phases by status, names the phase the loop would take next, quotes the verifiers, and states the ownership verdict.

`/10x:manual Refs`
Explains what the field ties a phase to, why `none` is legal, and points at `_shared/references/plan-format.md`.
