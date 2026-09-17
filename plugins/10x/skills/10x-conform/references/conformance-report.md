# Standard conformance: <repo>

**Standard:** v<manifest_version>  **Repo stamp:** v<repo_version> (<N> revisions behind)
**Types detected:** <e.g. go go-service web-app>
**Profile:** <private | internal | public> (<declared in CLAUDE.md | CONFORM_PROFILE | default>)
**Score:** P0 <pass>/<applicable> . P1 <pass>/<applicable> . P2 <pass>/<applicable>
**Verdict:** <CONFORMANT | P0 DRIFT | P1 DRIFT>

## Checks

| id | dim | sev | status | finding (confirmed) | remediation |
|----|-----|-----|--------|---------------------|-------------|
| ci.audit | ci | P0 | PASS/PARTIAL/FAIL/N-A | one line, evidence-backed | skill/ref, agent |
| version.stamp | version | P0 | ... | ... | 10x-makefile/makefile-go.md, coder-agent |
| ... | | | | | |

Status legend: PASS (probe green, confirmed) . PARTIAL (equivalent but not the
canonical form) . FAIL (confirmed gap) . N-A (check does not apply to these types,
or was dropped by the active profile).

The `sev` column is the **effective** severity for the active profile, not the
manifest baseline. When a profile lowered or dropped a check, say so in the finding
column, so nobody reads a shrunken scope as a repo that improved.

## Dropped by profile

Checks the active profile removed, listed by name rather than left silent. A profile
narrows what is asked, and the reader is entitled to see what was not asked.

- <id> (baseline <sev>): <expected>, dropped under `<profile>`

## Drift since v<repo_version>

Standard items this repo predates (from the manifest, newer than the repo stamp):

- <id> (<sev>): <expected>

## Remediation plan

### P0 (do first: security / correctness / supply chain)
- [ ] <id>: <concrete action> (<skill>/<ref>, <agent>)

### P1 (parity / consistency)
- [ ] <id>: <action>

### P2 (polish)
- [ ] <id>: <action>

## Judgment checks (agent-verified, not mechanizable)

- docs.no_drift: <PASS/FAIL> . <which documented targets/tags do not exist, if any>

## How this was produced

- Runner: `sh 10x-conform/references/conform.sh <target>` (the global runner in the plugin; not copied into the repo), manifest `_shared/references/standard.yml` v<manifest_version>.
- Profile: <name>, resolved from <source>. Undeclared repos run as `public`.
- Every P0 FAIL was confirmed in source; probe-only leads are marked PARTIAL.
- For `go.work` repos, per-module runs are listed separately above.

Fill every `<...>` placeholder above, then delete this line: a written report contains no angle-bracket placeholder and not this instruction.
