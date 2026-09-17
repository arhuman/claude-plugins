---
description: 'Diagnose a repo against the 10x engineering standard (Makefile, CI, Docker, versioning, tests, governance, security headers, supply chain) and report drift. Read-only: never modifies the repo.'
argument-hint: "[repo-path]"
disable-model-invocation: true
---

## Usage
`/check_conform [repo-path]`  (default path: `.`)

Read-only diagnosis. To apply the fixes, run `/make_conform` instead.

## Context
- Target: $ARGUMENTS
- Standard manifest (source of truth): `skills/_shared/references/standard.yml`
- Global runner (not copied into the repo): `skills/10x-conform/references/conform.sh`

## Workflow

1. Load the `10x-conform` skill and read `standard.yml`.
2. Run `sh skills/10x-conform/references/conform.sh <repo-path>` for the mechanizable PASS/FAIL/N-A. For a `go.work` workspace, run once per module (the root reports as `go-lib`). The runner resolves the audience profile from `CONFORM_PROFILE`, then `10x-profile:` in the target's `CLAUDE.md`, then `public`; note which applied.
3. Confirm each P0 FAIL in the source (a probe is a lead, not a verdict); mark equivalent-but-noncanonical implementations PARTIAL. Run the `manual: true` judgment checks (e.g. `docs.no_drift`) yourself.
4. Produce the report from `skills/10x-conform/references/conformance-report.md`: headline score, per-check table, drift versus the repo's stamped `standard_version`, and a remediation plan grouped by severity. Write it to `.claude/doc/conform-<repo>.md`.
5. Present the verdict (CONFORMANT / P0 DRIFT / P1 DRIFT), the P0 count, and the report path.

## Constraints
- Do not modify the audited repo. This command diagnoses only.
- Never report an unconfirmed P0. Never lower a threshold, delete a check, or narrow the profile to pass.
- Always state the active profile and what it dropped. A headline score without its profile is unreadable.
- Never vendor the runner into the audited repo; it runs from the plugin.
