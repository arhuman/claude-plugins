---
description: 'Bring a repo up to the 10x engineering standard: diagnose drift, then dispatch the manifest remediations (Makefile, CI, Docker, versioning, governance, security headers, supply chain) and commit the fixes. Modifies the repo; never pushes or opens a PR.'
---

## Usage
`/make_conform [repo-path]`  (default path: `.`)

Diagnoses, then applies the fixes. For a read-only report, use `/check_conform`.

## Context
- Target: $ARGUMENTS
- Standard manifest (source of truth): `~/.config/opencode/skills/_shared/references/standard.yml`
- Global runner (not copied into the repo): `~/.config/opencode/skills/10x-conform/references/conform.sh`

## Workflow

1. Run the shared diagnosis steps 1-4: `~/.config/opencode/skills/10x-conform/references/diagnose-steps.md`.
2. For each confirmed FAIL, dispatch its `remediation` per the skill's Remediation dispatch table, then re-run the runner to confirm the fix.
3. Commit the result per the skill's Commands section: one atomic commit per dimension fixed, following the repo's commit convention. Never push or open a PR; publishing is the operator's separate call. List judgment and design deltas for a human, never auto-applied.
4. Present the verdict, the P0 count, the fixes applied, the judgment items left for a human, and the report path.

## Constraints
- The `10x-conform` skill's MUST DO and MUST NOT lists apply in full (no unconfirmed P0, no threshold or profile games, no silent judgment fixes, runner never vendored, nothing published); this command does not restate them.
