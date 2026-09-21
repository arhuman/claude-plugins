# Project Documentation Artifacts

Templates and structure for the documentation set a mature project ships. Adapt
each to the project; do not paste them verbatim. Follow the skill's style rules:
no em dashes, no emojis, no filler, active voice.

## CONTRIBUTING.md

Structure:
- Prerequisites (language/tool versions, how to get a working checkout).
- Getting started: the build and test commands to confirm a clean checkout works.
- A useful-targets table (from the Makefile): `make build`, `make test`, `make audit`, `make cover`.
- The quality bar to clear before opening a PR.
- Commit and PR rules.

```markdown
# Contributing

## Prerequisites
- Go 1.26+ (the toolchain is pinned in go.mod)
- make, docker

## Getting started
    make build
    make test

## Useful targets
| Target | What it does |
|--------|--------------|
| make test  | short tests with the race detector |
| make audit | go mod verify + golangci-lint + govulncheck + coverage gate |
| make cover | coverage report, fails below the floor |

## Before you open a PR
- `make test` and `make audit` pass in the working tree.
- Coverage stays at or above the floor.
- Docs are updated in the same PR when a flag, tool, or config changes.

## Commits
- Conventional Commits, enforced by commitlint. Header under 72 characters.
- Breaking changes use `!` or a `BREAKING CHANGE:` footer.
- **Body is optional and terse.** If the header already says it, write no body. When a body helps, list what was addressed as short bullets, one per change, not narrative prose. Add rationale only where it is not obvious from the diff. Do not re-explain each change in full sentences.
  - Good body:
    ```
    - add mutex to products cache
    - drop unused ctx param from Insert
    - fix off-by-one in page offset
    ```
  - Bad body: a paragraph per change restating what the diff already shows ("This commit introduces a mutex to the products cache in order to ...").

## Tests define the contract
Changing a test's assertions changes the contract. Call it out in the PR
description so a reviewer reviews the behavior change, not just the code.
```

## SECURITY.md

```markdown
# Security Policy

## Supported versions
| Version | Supported |
|---------|-----------|
| 1.x     | yes       |
| < 1.0   | no        |

## Reporting a vulnerability
Do not open a public issue. Report privately via GitHub Security Advisories
(Security tab, "Report a vulnerability") or email security@example.com with a
subject prefixed `[SECURITY]`. We acknowledge within N business days.

## Security posture
- Secrets are read from the environment, never committed.
- Dependencies are scanned with govulncheck in CI.
- Input from the network is size-limited and validated.

## Known limitations
State the honest gaps (for example, a TOCTOU race, a trust assumption). A reader
deciding whether to deploy this needs the real boundary, not a claim of perfection.
```

## AGENTS.md (or CLAUDE.md)

Keep it imperative and short: commands, invariants, and a map of where things are
documented. It is a control surface for an agent, not prose for a human reader.

```markdown
# AGENTS.md

## Commands
- Build: `make build`
- Test: `make test` (race) / `make audit` (full gate)

## Architecture invariants (load-bearing)
- Business logic lives only in internal/<domain>; CLI/HTTP/MCP are thin adapters.
- Downstream packages never import upstream ones (data flows one direction).
- Every wrapped error is prefixed with its package name.

## Where things are documented
- Domain language: CONTEXT.md
- Decisions: docs/adr/
- Changes: CHANGELOG.md
```

## CONTEXT.md

The authoritative glossary for the project's ubiquitous language. ADRs must keep
UI, code, and docs from drifting away from the terms defined here.

```markdown
# Context

## Purpose
One paragraph: what this system is and the problem it solves.

## Core domain model
A small diagram (ASCII is fine) of the main entities and how they relate.

## Terms
| Term | Meaning | Not to be confused with |
|------|---------|-------------------------|
| Spool | the append-only staging buffer | the sealed segment it flushes into |

## Current state
What is built, what is in progress, what the current priority is.
```

## THIRD-PARTY-NOTICES.md

Required when the repo vendors third-party code or assets. It scopes the project
license and lists each vendored item.

```markdown
# Third-Party Notices

This project is licensed under <LICENSE>. It includes third-party components
under their own licenses, listed below.

## <component name>
- Path: vendor/<path> or assets/<path>
- Source: <url>
- Retrieved: <date>
- License: <SPDX id> (full text in <path>/LICENSE)

Fill every <...> placeholder above and delete this line: the written file contains no angle-bracket placeholder.
```
