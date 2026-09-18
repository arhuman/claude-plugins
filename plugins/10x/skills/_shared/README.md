# _shared: cross-skill references (not a skill)

This directory has no `SKILL.md`, so it is not loaded as a skill. It is the
single home for configuration that more than one 10x skill needs to agree on,
so the same fact is not pinned to three different values in three places.

Skills reference these files with a sibling-relative path, e.g. from
`lang-go/SKILL.md`: `../_shared/references/versions.md`.

## Contents

| File | Owner concept | Consumed by |
|------|---------------|-------------|
| `references/plan-format.md` | Plan file and phase shape, `Refs:` grammar, status enum, ordering | `loop`, `steering` |
| `references/ux-contract.md` | `docs/ux.md` shape: screens, components, state rules, `ui_paths` | `steering`, `10x-frontend-design` |
| `references/standard.yml` | The machine-checkable engineering standard: checks, severities, profiles, probes | `conform` (its runner is a generated view of this file) |
| `references/skill-standard.md` | How a SKILL.md is written: description clauses, Done-when blocks, one-fact-one-home | every skill, and skill reviews |
| `references/artifacts.md` | Registry of every artifact 10x writes or reads in a target project: path, writer, reader, format, lifecycle | `steering`, `loop`, `conform`, `testing`, commands |
| `references/concurrency.md` | Multi-session work on one repo: jj workspace isolation plus the plan-file claim protocol | `loop`, `commit`, `plan-format.md` |
| `references/claim.sh` | Compare-and-swap phase claiming: mutex + claim token, the mechanism `plan-format.md` specifies | `loop` |
| `references/resolve-paths.sh` | Steering-document paths for a repo, owned/foreign resolved once | `loop`, `verify-plan.sh`, `steering` |
| `references/versions.md` | Pinned Go toolchain, golangci-lint/govulncheck, and GitHub Actions versions | `lang-go`, `makefile`, `ci` |
| `references/golangci-minimal.yml` | golangci-lint **minimal** tier | `lang-go`, `makefile` |
| `references/golangci-strict.yml` | golangci-lint **strict** tier (ratchet discipline) | `lang-go`, `makefile` |

## golangci-lint tier ladder

Three configs, increasing strictness. Pick the tier that matches project
maturity; the binary version is pinned in `references/versions.md`.

1. **minimal**: `references/golangci-minimal.yml`. `default: none` + 7 linters.
   Correctness/resource bugs only, no complexity program. Small tools, libs,
   early-stage code.
2. **standard**: `../10x-makefile/references/.golangci.yml`. `default: none` +
   11 linters, encoding the shared complexity/duplication thresholds
   (gocyclo>10, gocognit>15, funlen 80, nestif 4, dupl 50) so daily linting
   measures what a review measures. Default tier for scaffolded projects.
3. **strict**: `references/golangci-strict.yml`. `default: standard` + ~30
   linters (security, error-wrapping, performance) and a fully-configured
   revive, with ratchet-based complexity gates. Mature services paying down
   complexity debt.

A review-grading consumer outside this public tree keeps its own fallback
config for repos with no `.golangci.yml`; it encodes the same thresholds as
the standard tier.
