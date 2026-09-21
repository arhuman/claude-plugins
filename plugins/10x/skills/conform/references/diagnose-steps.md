# Shared diagnosis steps

The four steps every conformance run performs before its mode-specific work.
They live here once so `check_conform`, `make_conform`, and `conform-agent`
cannot drift from each other; each cites this file instead of restating it.

1. Load the `conform` skill and read `../../_shared/references/standard.yml`.
2. Run `sh <skill-dir>/references/conform.sh <repo-path>` (default `.`) for the
   mechanizable PASS/FAIL/N-A. For a `go.work` workspace, run once per module:
   the root reports as `go-lib`. The runner resolves the audience profile (see
   the skill's Audience profiles section for the resolution order); note which
   applied and where it came from.
3. Confirm each P0 FAIL in the source per the skill's lead-not-verdict rule,
   and mark equivalent-but-noncanonical implementations PARTIAL. Run the
   `manual: true` judgment checks (e.g. `docs.no_drift`) yourself; the runner
   skips them.
4. Produce the report from `conformance-report.md` (headline score, per-check
   table with effective severities, profile and its source, "Dropped by
   profile" list, drift versus the repo's stamped `standard_version`,
   remediation grouped by severity) and write it to
   `.claude/doc/conform-<repo>.md`.
