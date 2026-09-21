---
description: 'Diagnose a repo against the 10x engineering standard (Makefile, CI, Docker, versioning, tests, governance, security headers, supply chain) and report drift. Read-only: never modifies the repo.'
---

## Usage
`/check_conform [repo-path]`  (default path: `.`)

Read-only diagnosis. To apply the fixes, run `/make_conform` instead.

## Context
- Target: $ARGUMENTS
- Standard manifest (source of truth): `~/.config/opencode/skills/_shared/references/standard.yml`
- Global runner (not copied into the repo): `skills/conform/references/conform.sh`

## Workflow

1. Run the shared diagnosis steps 1-4: `skills/conform/references/diagnose-steps.md` (load the skill, run the runner, confirm P0 leads in source, write the report to `.claude/doc/conform-<repo>.md`).
2. Present the verdict (CONFORMANT / P0 DRIFT / P1 DRIFT), the P0 count, and the report path.

## Constraints
- Do not modify the audited repo. This command diagnoses only.
- The `conform` skill's MUST DO and MUST NOT lists apply in full (profile stated with its source, no unconfirmed P0, no threshold or profile games, runner never vendored); this command does not restate them.
