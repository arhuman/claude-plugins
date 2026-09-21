# Project Documentation Artifacts

Apply [documentation style](../SKILL.md#style-global-rules). Adapt contracts to verified project facts; never paste example versions, addresses, commands or invariants as facts.

## CONTRIBUTING.md

Include prerequisites/tool versions and checkout setup; build/test commands proving a clean checkout; a Makefile target table (build, test, audit, cover as available); pre-PR quality bar; commit/PR rules.

Pre-PR contract: test and audit pass, coverage meets the floor, and flag/tool/config changes update docs in the same PR. Call assertion changes out in the PR description because they change the test contract.

Commit convention: Conventional Commits enforced by commitlint, header under 72 characters, `!` or `BREAKING CHANGE:` footer for breaking changes. Body optional: omit if header suffices; otherwise short change bullets, rationale only when not obvious from diff. No narrative restatement.

## SECURITY.md

Include supported-version table; private vulnerability-report channel (GitHub Security Advisories or actual security email, `[SECURITY]` subject); acknowledgement window in business days. No public vulnerability issues.

State actual security posture: environment-sourced, uncommitted secrets; CI dependency scanning (govulncheck for Go); size-limited, validated network input. Disclose honest limitations such as races and trust assumptions. Verify project commitments before claiming them.

## AGENTS.md (or CLAUDE.md)

Keep imperative and short: build/test/full-gate commands, load-bearing architecture invariants, documentation map (domain language in CONTEXT.md, decisions in docs/adr/, changes in CHANGELOG.md). Record actual domain/adapter boundaries, dependency direction and error conventions, not generic example architecture.

## CONTEXT.md

Authoritative domain glossary: one-paragraph purpose, small entity/relationship diagram, terms table with `Term | Meaning | Not to be confused with`, current built/in-progress/priority state. ADRs keep UI, code and docs aligned with these terms.

## THIRD-PARTY-NOTICES.md

For vendored code/assets, state project license and that components retain their own licenses. Per component include name, repository path, source URL, retrieval date, SPDX license ID and full-license-text path. Fill every placeholder; leave none in the written file.
