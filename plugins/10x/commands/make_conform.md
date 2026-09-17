---
description: 'Bring a repo up to the 10x engineering standard: diagnose drift, then dispatch the manifest remediations (Makefile, CI, Docker, versioning, governance, security headers, supply chain) and open one PR. Modifies the repo.'
argument-hint: "[repo-path]"
disable-model-invocation: true
---

## Usage
`/make_conform [repo-path]`  (default path: `.`)

Diagnoses, then applies the fixes. For a read-only report, use `/check_conform`.

## Context
- Target: $ARGUMENTS
- Standard manifest (source of truth): `skills/_shared/references/standard.yml`
- Global runner (not copied into the repo): `skills/10x-conform/references/conform.sh`

## Workflow

1. Load the `10x-conform` skill and read `standard.yml`.
2. Run `sh skills/10x-conform/references/conform.sh <repo-path>` for the mechanizable PASS/FAIL/N-A. For a `go.work` workspace, run once per module (the root reports as `go-lib`).
3. Confirm each P0 FAIL in the source (a probe is a lead, not a verdict); mark equivalent-but-noncanonical implementations PARTIAL. Run the `manual: true` judgment checks (e.g. `docs.no_drift`) yourself.
4. Produce the report from `skills/10x-conform/references/conformance-report.md` and write it to `.claude/doc/conform-<repo>.md`.
5. For each confirmed FAIL, dispatch its `remediation` (agent + skill/ref from the manifest) to apply the canonical template, then re-run the runner to confirm the fix. Mechanical deltas go to `fixer-agent`/`docker-agent`; design deltas to `coder-agent`.
6. Open one PR ("bring repo up to standard vX.Y"). List judgment and design items in the PR body for a human; never auto-apply them.
7. Present the verdict, the P0 count, the fixes applied, and the report path.

## Constraints
- Never report an unconfirmed P0. Never lower a threshold or delete a check to pass.
- Silently auto-fixing judgment or design deltas is forbidden; surface them for a human.
- Never vendor the runner into the audited repo; it runs from the plugin.
