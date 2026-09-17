---
name: 10x-makefile
description: 'Best practices for project Makefiles. Use when creating or modifying a Makefile: adding/reviewing targets, PHONY declarations, tab indentation, docker compose v2 targets. Supports Go with dedicated targets. Not for release automation, goreleaser, or CI workflows: use 10x-ci.'
---
# 10x Makefile

## Reference

| Resource | Purpose |
|----------|---------|
| `./references/makefile-base.md` | Universal Makefile skeleton (help, docker, confirm) |
| `./references/makefile-go.md` | Go targets (build+ldflags, test, cover gate, audit, checklen, tidy, tools) |
| `./references/version-go.md` | The Go version package the ldflags target: three stamped vars + the `debug.ReadBuildInfo` fallback that covers `go install` |
| `./references/makefile-compose.md` | Multi-environment docker compose targets (base + local/prod/test overlays) |
| `./references/.golangci.yml` | golangci-lint v2 config, **standard** tier (Go only). Minimal and strict tiers live in `../_shared/references/`; see `../_shared/README.md` |
| `../_shared/references/versions.md` | Pinned golangci-lint, govulncheck, Go, and GitHub Actions versions: pin the `tools` target here |

## MUST DO

- Start from `makefile-base.md` as the skeleton
- When the project is Go, merge targets from `makefile-go.md` into the skeleton
- Follow the exact structure: variables → PHONY → standard targets → utility targets → project-specific targets
- Sort all targets alphabetically within each section
- Use TABS for indentation, never spaces
- Document every target with `## target: description` comment
- Add all targets to the `.PHONY` declaration
- Use `docker compose` (v2), never `docker-compose` (v1)
- Silence non-essential commands with `@`
- Keep `.DEFAULT_GOAL := help`
- Use the standard `help` target: `## target: description` comments rendered by the `sed`/`column` one-liner. This is the chosen convention over the inline `target: ## desc` + colorized-awk alternative: it is portable, needs no color support, and keeps descriptions off the recipe line. Do not switch styles per project.
- For Go: inject version metadata via `-ldflags` in `build` (`VERSION`/`COMMIT`/`BUILD_DATE`, with a commit-timestamp `BUILD_DATE` for reproducible rebuilds), and gate coverage in the `cover` target (fail below `COVER_MIN`; the default value lives in `makefile-go.md`). `audit` depends on `cover`.
- For Go: pair those ldflags with the `version-go.md` package. `go install <module>@latest` applies none of them, so without its `debug.ReadBuildInfo` fallback a tagged release reports `dev (unknown, unknown)` to every user who installs it the documented way, while the Makefile still looks correct.
- Pin tool versions (golangci-lint, govulncheck) to `../_shared/references/versions.md`; the same versions must appear in the CI `lint` job.
- Bootstrap missing tools before use: `@which golangci-lint > /dev/null || $(MAKE) tools`.

## MUST NOT

- Add targets not explicitly requested: the templates define the minimal standard
- Change the `help` target implementation
- Use `docker-compose` (v1 syntax)
- Use spaces for indentation

## Done when

- `make -n <target>` exits 0 for every target added or modified (dry-run proves the Makefile parses and the recipe expands).
- `make help` lists every added target with its description; a target missing from help lacks its `## target: description` line.
- `grep -nE '^ +\S' Makefile` finds no space-indented recipe line.
- Every added target appears in the `.PHONY` declaration (`grep -n '.PHONY' Makefile` includes it), unless it produces a real file.
- `grep -n 'docker-compose' Makefile` is empty (compose v2 only).
- After merging `makefile-go.md`: `grep -n 'progname' Makefile` is empty, and `GOLANGCI_VERSION`/`GOVULNCHECK_VERSION` equal the pins in `../_shared/references/versions.md`.
