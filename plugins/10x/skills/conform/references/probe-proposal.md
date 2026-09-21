# Probe proposal: <short incident slug>

**Repo:** <repo> (<types detected>)  **Discovered:** <date>
**Existing coverage:** <id(s) of related check(s) and what they reported at the time (PASS / N-A / did not exist)>

## What happened

<One paragraph: the real, deployed problem. What broke, in production or in a
real run, that no check flagged before it happened.>

## Why the standard missed it

<Name the specific gap. Either: an existing check's `probe` or `applies_to` was
too narrow to catch this case (cite its `id`), or: no check in `standard.yml`
covers this dimension at all. If an existing check should have caught this and
only has a bug in its probe, this is a fix to that check, not a new proposal -
say so instead of filling in the section below.>

## Proposed check

```yaml
- id: <dimension.thing>
  dimension: <makefile | ci | docker | compose | version | tests | governance | lint | supply-chain>
  applies_to: [<repo types>]
  severity: <P0 | P1 | P2>
  probe: '<POSIX sh + grep/test one-liner; exit 0 = PASS>'
  expected: "<prose the agent evaluates and the report prints>"
  remediation: {skill: <skill>, ref: <ref>, agent: <agent, if any>}
```

**Severity justification:** <why P0/P1/P2 - P0 is reserved for security/correctness and never varies by profile>
**Confirmed FAIL:** <the incident repo, run against this probe, fails as expected>
**Confirmed PASS:** <at least one other repo where this probe passes, so it is not overly broad>

## Status

- [ ] Reviewed by a human
- [ ] Added to `../../_shared/references/standard.yml` (`standard_version` bumped, dated comment added at the top per the existing convention)
- [ ] Matching pipe-delimited line added to `conform.sh` in the same position/format
- [ ] Plugin version bumped (`plugins/10x/.claude-plugin/plugin.json`)

Until every box above is checked, this is a proposal only: `standard.yml` and
`conform.sh` are unchanged, and no repo is held to this check yet.

Fill every `<...>` placeholder above, then delete this line: a written proposal contains no angle-bracket placeholder and not this instruction.
