---
name: 10x-makefile
description: Best practices for Go project Makefiles. Use when creating or modifying a Go project Makefile: adding/reviewing targets, PHONY declarations, tab indentation, docker compose v2 targets.
---
# 10x Makefile

## Reference

| Resource | Purpose |
|----------|---------|
| `./references/makefile-template.md` | Standard template with all required targets |

## MUST DO

- Follow the exact structure in the template: variables → PHONY → standard targets → utility targets → project-specific targets
- Sort all targets alphabetically within each section
- Use TABS for indentation, never spaces
- Document every target with `## target: description` comment
- Add all targets to the `.PHONY` declaration
- Use `docker compose` (v2), never `docker-compose` (v1)
- Silence non-essential commands with `@`
- List `tools` as a dependency for targets that require external tools (e.g., `audit`, `doc`)

## MUST NOT

- Add targets not explicitly requested — the template is the complete minimal standard
- Change the `help` target implementation
- Use `docker-compose` (v1 syntax)
- Use spaces for indentation
