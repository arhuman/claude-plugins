---
name: makefile
description: 'Project Makefile rules: targets, PHONY, tabs, Compose v2 and Go targets. Use when creating, modifying or reviewing Makefiles. For CI workflows and goreleaser use `ci`.'
---
# 10x Makefile

## Reference

Load by task:

| Resource | Use |
|----------|-----|
| `references/makefile-base.md` | Always: skeleton, exact help, confirm |
| `references/makefile-go.md`, `references/version-go.md` | Go: targets, gates, ldflags and go-install fallback |
| `references/makefile-compose.md` | Multi-environment Compose targets |
| `references/.golangci.yml` | Go standard tier; other tiers in `../_shared/README.md` |
| `../_shared/references/versions.md` | Tool pins, identical in CI |

## MUST DO

- Merge language targets into base skeleton. Order: variables, PHONY, standard, utility, project-specific targets; alphabetize within sections.
- Tab-indent recipes, silence nonessential commands with `@`, document every target as `## target: description`; declare non-file targets `.PHONY`.
- Keep `.DEFAULT_GOAL := help` and the exact reference `sed`/`column` help implementation, not inline descriptions/colorized awk.
- Use `docker compose` v2.
- Go: stamp `VERSION`/`COMMIT`/`BUILD_DATE` via ldflags; date is commit timestamp for reproducibility. Load version package reference for the `debug.ReadBuildInfo` fallback used by `go install`.
- Go: `cover` fails below `COVER_MIN` (default in Go reference); `audit` depends on `cover`.
- Tools use shared pins, matching CI/config schema; bootstrap before use (`@which golangci-lint > /dev/null || $(MAKE) tools`).

## MUST NOT

Add unrequested targets beyond the minimal templates, change help conventions, use space-indented recipes or Compose v1.

## Done when

- `make -n <target>` succeeds for every changed target; `make help` lists each description.
- No space-indented recipes; all non-file targets in `.PHONY`; all Compose commands v2.
- Go merge: no `progname` placeholders; `GOLANGCI_VERSION`/`GOVULNCHECK_VERSION` match shared pins.
