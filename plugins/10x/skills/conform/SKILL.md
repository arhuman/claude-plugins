---
name: conform
description: 'Detect and enforce a repo''s drift from the 10x engineering standard (Makefile, CI, Docker, versioning, tests, governance, security headers, supply chain). Use when asked to audit a repo for standard conformance, check for drift, bring a repo up to standard, add a conformance gate to CI, or after scaffolding a project to stamp and verify its standard version. Not for grading code quality: a scored review of architecture, security, or correctness is the built-in /code-review; conform measures drift from the standard manifest, nothing else.'
---
# 10x Conform

The generator makes *new* code follow the standard. This skill does the other
half: detect when an *existing* repo has drifted, and enforce bringing it back.
It reads one machine-checkable manifest, `../_shared/references/standard.yml`,
which is the same single source of truth the generator emits from, so "what we
emit" and "what we enforce" cannot diverge.

This is distinct from `make verify-templates` (which checks the *templates'*
internal consistency against `versions.md`). Conform checks a *real repo*.

## Reference

| Resource | Purpose |
|----------|---------|
| `../_shared/references/standard.yml` | Authoritative manifest: every check, its `applies_to`, `severity`, `profiles`, `probe`, `expected`, `remediation`, plus the `profiles` block and `default_profile`. Edit here first. |
| `./references/conform.sh` | Portable POSIX runner (a generated view of the manifest). Global: it lives here in the plugin and runs against any repo via `sh ./references/conform.sh <target>`. It is **not** copied into audited repos. |
| `./references/conformance-report.md` | The report template the agent fills. |
| `./references/diagnose-steps.md` | The four shared diagnosis steps `check_conform`, `make_conform`, and `conform-agent` cite instead of restating. |
| `./references/verify-lockstep.sh` | Fails when `standard.yml` and `conform.sh` diverge (version, check ids, severities, and the probe strings themselves). Run it after any manifest edit; `--self-test` proves it catches each drift kind. |
| `./references/probe-proposal.md` | Template for drafting a candidate new/amended check from a confirmed false negative, before it touches `standard.yml`. |

## Audience profiles

`applies_to` answers "what kind of artifact is this" (go-service, go-cli, web-app).
The profile answers the orthogonal question: **who consumes it**. Both are needed,
because a private tool and a published library can be the same artifact type while
owing their readers completely different things.

Who each profile is (the audience definitions) lives in the manifest's `profiles`
block in `../_shared/references/standard.yml`; only the enforcement deltas are
restated here:

| Profile | What changes |
|---------|--------------|
| `private` | SECURITY.md, CONTRIBUTING.md, CODEOWNERS and signed SBOMs drop to N/A; release automation drops to P2 |
| `internal` | CODEOWNERS rises to P1 (review routing is the real need at this size); disclosure and contribution docs stay advisory |
| `public` | Everything at full weight. Changelog and signed artifacts rise to P1: consumers cannot read the commit log for context or trust an unsigned binary |

Only governance, release and supply-chain checks vary. **P0 never does.** Exposure
is a property of the deployment, not of the audience: a private service behind a
Traefik prod overlay faces the same internet as a public one, so `docker.nonroot`,
`compose.security_headers`, `ci.audit`, `lint.config` and `version.stamp` apply
identically everywhere. A profile that could weaken a P0 would be a way to make a
repo pass by relabelling it, which is the failure mode this design exists to avoid.

Resolution order: `CONFORM_PROFILE` env, then `10x-profile: <name>` in the repo's
`CLAUDE.md` (beside the `10x-standard: vX.Y` stamp), then `public`.

The default is the strictest on purpose. An undeclared repo must never quietly lose
checks: narrowing the standard is an explicit act that leaves a trace in the repo,
and the runner prints the active profile and the count it dropped on every run.

## MUST DO

- Run the global runner against the target repo (`sh ./references/conform.sh <target-dir>`, default `.`) for the mechanizable PASS/FAIL/N-A, then read `standard.yml` for severities, `expected` prose, and `remediation` pointers. One copy of the runner exists (in the plugin); never vendor it into the audited repo.
- Treat every probe result as a **lead, not a verdict**: confirm each P0 FAIL in the source before reporting it. A probe can miss an equivalent-but-differently-named implementation (e.g. a CI that runs lint+vuln+cover as separate steps instead of `make audit`); mark those PARTIAL, not FAIL.
- Run the judgment-only checks (`manual: true` in the manifest, e.g. `docs.no_drift`) yourself; the runner skips them.
- For `go.work` workspaces, run the runner **per module**, not only at root: a workspace root classifies as `go-lib`, so service checks (docker, compose, version) show N/A there.
- Resolve the profile before reading any result, and name it in the report header with where it came from. Report **effective** severities (post-profile), and list what the profile dropped under "Dropped by profile" rather than leaving the narrower scope implicit: a shrunken question set is not an improved repo.
- Produce the report from `references/conformance-report.md`: headline score, per-check table, the **drift delta** versus the repo's stamped `standard_version`, and a remediation plan grouped by severity.
- Keep `standard.yml` and `conform.sh` in lockstep. Add a check to the manifest first, then regenerate the runner. Never add a check only to the runner. Prove it with `sh ./references/verify-lockstep.sh` (exit 0) before committing any edit to either file: the rule was held by prose alone until a real slip shipped a runner that never executed the newest check.
- When a repo audit, a `make_conform` run, or a reported incident shows that a check PASSED (or no check existed) while a real, deployed problem happened anyway, that is a confirmed false negative in the standard itself, not only a bug in one repo. Capture it with `propose_probe` before or alongside fixing the instance, so the lesson survives past this conversation.

## MUST NOT

- Report a P0 FAIL you have not confirmed in the source.
- Invent a result for a check that could not be evaluated (probe errored, tool missing, surface unreadable). Record it in the report as not evaluated, with the reason, and exclude it from the score denominator: an unanswered question is not a PASS and not a FAIL.
- Hardcode a check only in `conform.sh`: `standard.yml` is the source of truth.
- Silently auto-fix judgment or design deltas. Route mechanical deltas to `fixer-agent`/`docker-agent`; list judgment items for a human.
- Lower a threshold or delete a check to make a repo pass. Raise the repo, or bump the standard deliberately (and `standard_version` with it).
- Pick or change a repo's profile to clear a failing check. The profile describes who consumes the repo; it is a fact about the project, not a dial. If a `public` repo fails public checks, the finding is real.
- Give a P0 a profile override. Security and correctness do not vary by audience, and a profile that could weaken one becomes a relabelling exploit.
- Count a profile-dropped check as a pass, or report a headline score without saying which profile produced it.
- Apply a `propose_probe` draft to `standard.yml` or `conform.sh` without explicit human approval, or propose a new check that duplicates an existing one in spirit (fix that check's `probe` instead, and say so).
- Push, open a pull request, or otherwise publish what `make_conform` produced. It stops at the commit; the operator decides when anything leaves the machine.
- Rewrite history the operator did not ask you to touch. Commits parked off the main line are parked on purpose, and a detached head is a decision, not damage. Confirm what a commit is for before rebasing, squashing or abandoning it, and never "repair" a topology you did not create.
- Trust a `jj split` reported as empty. A commit can be empty of the paths you selected while still carrying an unrelated deletion, which then silently unignores whole trees. Check what a split actually produced before building on it.

## Commands

Three commands. `check_conform` and `make_conform` run the global runner from the
plugin against a target repo; neither writes the runner into that repo. `propose_probe`
never touches a target repo at all - it only drafts a change to the standard itself.

- **`check_conform`** [Detect, default]: run the runner against the target repo, confirm P0 leads in source, and produce the diagnosis (the report). Read-only: it never modifies the audited repo.
- **`make_conform`** [Fix]: run the diagnosis, then for each confirmed FAIL dispatch its `remediation` (agent + skill/ref from the manifest) to apply the canonical template, re-run the runner to confirm, and **commit** the result. One atomic commit per dimension fixed, following the repo's commit convention. **Never push, never open a PR**: publishing is the operator's call, made separately and on request. Judgment and design deltas are listed for a human, never auto-applied.
- **`propose_probe`** [Capture]: turn a confirmed false negative (a check passed, or none existed, while a real incident happened) into a draft addition to `standard.yml`, using `references/probe-proposal.md`. Writes the draft to `.claude/doc/` and stops for review; applying an approved draft follows the same lockstep rule as any other manifest edit (manifest first, then the runner, then the plugin version).

Remediation dispatch for `make_conform` [Fix]:

| remediation.agent | Delegate to | For |
|-------------------|-------------|-----|
| docker-agent | `docker-agent` | Dockerfile / compose (nonroot, headers, healthcheck) |
| coder-agent | `coder-agent` | version stamping, new targets, design deltas |
| (none) / mechanical | `fixer-agent` | dropping in a template file (ci.yml, dependabot.yml, SECURITY.md) |
| docs updates after a fix | `documentation-agent` | README / CHANGELOG / ADR |

Done when, per command:

- `check_conform`: the runner has actually run against the target (`sh ./references/conform.sh <target>`; exit 0 = no P0 drift, 1 = P0 drift, 2 = target unreachable) and its exit code is quoted in the report. The report file exists, names the active profile and its source in the header, leaves no `<...>` placeholder (`grep -cE '<[a-z_]+>' <report>` returns 0), and every P0 FAIL row cites the source evidence that confirmed it (or is downgraded to PARTIAL).
- `make_conform`: re-running the runner on the fixed repo exits 0, or every remaining FAIL is listed as a judgment item for a human; `jj log` shows one commit per dimension fixed; nothing was pushed.
- `propose_probe`: the draft file exists under `.claude/doc/`, follows `references/probe-proposal.md` with no `<...>` placeholder left, and `standard.yml` and `conform.sh` are byte-identical to before the run (`jj diff` shows neither file touched).

## Enforce in CI (optional)

The runner is dependency-free but lives in the plugin, not the repo, so CI fetches
it at job time instead of committing a copy. Drop-in job:

```yaml
# .github/workflows/conform.yml
name: conform
on:
  pull_request:
  schedule: [{ cron: "0 6 * * 1" }]   # weekly drift report
permissions: { contents: read }
jobs:
  conform:
    runs-on: ubuntu-latest
    env:
      # raw URL of skills/conform/references/conform.sh in the 10x plugin
      CONFORM_RUNNER_URL: <raw-url-to-conform.sh>
      # omit to let the runner read 10x-profile: from CLAUDE.md (or default to public)
      CONFORM_PROFILE: <private | internal | public>
    steps:
      - uses: actions/checkout@v7
      - name: fetch runner
        run: curl -sfL "$CONFORM_RUNNER_URL" -o /tmp/conform.sh
      - name: standard conformance
        run: |
          # PR: fail on P0 drift. schedule: report only.
          if [ "${{ github.event_name }}" = pull_request ]; then
            sh /tmp/conform.sh .
          else
            CONFORM_WARN=1 sh /tmp/conform.sh .
          fi
```

## The repo stamp (drift over time)

The runner carries `STANDARD_VERSION`; also record `10x-standard: vX.Y` in the
repo's `CLAUDE.md`. Compare that stamp to `standard.yml`'s `standard_version` to
report exactly which newer standard items a repo predates ("N revisions behind;
new since vX.Y: ...").

Record the profile on the next line, so both facts live together and a reader sees
what standard the repo claims and which audience it claims it for:

```markdown
10x-standard: v1.8
10x-profile: private
```

An absent `10x-profile` line means `public`. Adding one is how a repo opts out of
the checks its audience does not justify, and the diff that adds it is the record
of that decision.

No 10x component writes this stamp automatically: it is set by hand, or by
whoever scaffolds the repo, and only read by tooling (`conform.sh`,
`ownership.sh`). The full writer/reader table is
`../_shared/references/artifacts.md`.

## Reachability

Invoke via the `/check_conform` (diagnose), `/make_conform` (fix), or `/propose_probe`
(capture) commands, or the `conform-agent`. Do not leave it only
description-triggered: a scheduled CI job and a human must both be able to run
it on any repo at any time.
