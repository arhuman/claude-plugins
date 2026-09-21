---
description: 'Capture a confirmed conformance false negative (a check passed, or none existed, while a real deployed incident happened anyway) as a draft addition to the 10x engineering standard. Never edits standard.yml or conform.sh; writes a proposal for review.'
---

## Usage
`/propose_probe <incident description>`

Capture only. To apply an approved proposal, edit `standard.yml` and `conform.sh`
per `conform`'s lockstep rule, then bump the plugin version - do not do this
automatically.

## Context
- Incident: $ARGUMENTS
- Standard manifest (source of truth): `~/.config/opencode/skills/_shared/references/standard.yml`
- Global runner (not copied into the repo): `skills/conform/references/conform.sh`
- Template: `skills/conform/references/probe-proposal.md`

## Workflow

1. Load the `conform` skill and read `standard.yml`.
2. Identify which existing check(s), if any, are related to the incident, and confirm what they actually reported at the time (PASS / N-A / did not exist). If an existing check should have caught this and only has a bug in its `probe`, that is a fix to that check, not a new proposal - say so and stop here.
3. Draft the new (or amended) check using `probe-proposal.md`'s schema: `id`, `dimension`, `applies_to`, `severity`, `probe` (POSIX sh, dependency-free), `expected`, `remediation`. Confirm the probe against the incident repo (must FAIL) and at least one other repo of the same type (must PASS), so it is not overly broad.
4. Write the proposal to `.claude/doc/probe-proposal-<slug>.md` in the target repo. Do not touch `standard.yml` or `conform.sh`.
5. Present the proposal and stop. Wait for explicit approval before applying it.
6. Only once approved: add the entry to `standard.yml` (bump `standard_version`, add a dated comment block at the top per the existing convention), add the matching pipe-delimited line to `conform.sh` in the same format and position, and bump the plugin version (`plugins/10x/.claude-plugin/plugin.json`). Commit the standard change separately from any specific repo's remediation.

## Constraints
- Never edit `standard.yml` or `conform.sh` before the proposal is approved.
- Never propose a check that duplicates an existing one in spirit; fix the existing probe instead and say so.
- State explicitly which existing check, if any, should have caught this and why it did not, per `conform`'s lead-not-verdict rule.
