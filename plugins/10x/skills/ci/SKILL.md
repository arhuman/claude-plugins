---
name: ci
description: 'GitHub Actions CI/CD best practices for Go projects. Use when creating or reviewing CI workflows, release automation (goreleaser), dependabot, coverage gates, matrix builds, or service-backed integration jobs; especially when a repo has Makefile audit/build/test targets but no .github/workflows to run them. Not for auditing an existing repo''s CI against the 10x standard: the `conform` skill runs those checks.'
---
# 10x CI

CI and local must run the **same commands**. A workflow that reimplements what
`make audit` does will drift from it; a workflow that *calls* `make audit` cannot.
The primary trigger for this skill is a repo that already has Makefile quality
targets (`make build`, `make test`, `make audit`, `make cover`) but no
`.github/workflows/` to run them in CI.

## Reference

| Resource | Purpose |
|----------|---------|
| `./references/ci.yml` | CI workflow: matrix test, lint+vuln, commitlint, optional image scan + SAST, optional service-backed integration |
| `./references/release.yml` | Tag-triggered release workflow (goreleaser) |
| `./references/goreleaser.yaml` | goreleaser v2 config (multi-OS/arch, checksums, changelog, SBOM, cosign signing) |
| `./references/release-python.yml` | Python analogue: tag-triggered build + PyPI Trusted Publishing (satisfies `release.workflow` for `python-*` types) |
| `./references/dependabot.yml` | Weekly gomod + github-actions updates |
| `./references/shell-gates.md` | Dependency-free shell gates (license, public-tree), the `services:` health pattern, inline coverage-gate fallback, and the go.work multi-module release alternative |
| `../_shared/references/versions.md` | Pinned action + tool versions: the single source of truth CI must match |

## MUST DO

- Set least-privilege `permissions` at the workflow top: `contents: read` for CI, `contents: write` only in the release workflow.
- Add a `concurrency` group (`ci-${{ github.ref }}`, `cancel-in-progress: true`) so superseded runs are cancelled.
- Trigger on `push` to `main` and on `pull_request`.
- Run a Go version matrix with `fail-fast: false` and `go: ["<go.mod floor>", "stable"]`: the floor catches compatibility breaks, `stable` carries the latest security patches (and is what release builds ship with).
- **Call the Makefile targets** (`make build`, `make test`, `make audit`) rather than re-writing their commands in YAML, so CI and local never drift.
- Pin every action and tool version to `../_shared/references/versions.md`: it is the single home for the action majors and the golangci-lint/govulncheck pins, and it carries the rule that CI's golangci-lint equals the Makefile `tools` pin. Do not restate version numbers here or in a workflow comment; copy them from that file at scaffold time.
- Gate coverage in CI: `make audit` (which depends on `make cover`) fails below `COVER_MIN`. For repos without that target, use the inline awk gate in `shell-gates.md`.
- Build every build-tag variant so none rots (e.g. `go build -tags embed ./...`).
- Add `actions/setup-go` (it caches modules and build output) and prefer `go-version-file: go.mod` when not using a matrix.
- Ship a `dependabot.yml` covering both `gomod` and `github-actions`.
- Automate releases: tag `v*` triggers goreleaser building static, `-trimpath`, version-stamped binaries for linux/darwin/windows × amd64/arm64.
- Stamp `Version` from `v{{ .Version }}` in `goreleaser.yaml`: goreleaser's `.Version` drops the tag's leading `v`, so a release binary otherwise prints `mytool 1.4.0` where `make build` and `go install` both print `v1.4.0`. Archive names keep the unprefixed form.
- When `goreleaser.yaml` declares `sboms:`/`signs:` (it does, for `supply_chain.sign_sbom`), the release workflow MUST install their tools (`anchore/sbom-action/download-syft`, `sigstore/cosign-installer`) and grant `id-token: write`, or goreleaser fails with "syft/cosign: executable file not found".
- Sign into a Sigstore bundle (`--bundle=${signature}`, `${artifact}.sigstore.json`), never `--output-signature`/`--output-certificate`. cosign-installer v4 defaults to cosign 3, which writes the new bundle format, ignores those two flags, and dies on the `--bundle` path it was never given. The failure only appears on a tag, after the whole build has succeeded.

## MUST NOT

- Grant `write` permissions to the CI workflow (only the release workflow needs `contents: write`).
- Pin a golangci-lint version in CI that differs from the Makefile `tools` target or the committed `.golangci.yml` schema.
- Reimplement `make audit`/`make test` step-by-step in YAML when a Makefile target exists.
- Use `actions/checkout` without `fetch-depth: 0` in the release workflow (goreleaser needs full history/tags for the changelog).
- Leave a repo with Makefile quality targets but no workflow that runs them.

## Done when

- `actionlint` reports nothing on `.github/workflows/` (skip only if actionlint is not installed, and say so).
- `grep -E 'run: +make (build|test|audit)' .github/workflows/ci.yml` matches: CI calls the Makefile, it does not reimplement it.
- `grep -n 'contents: read' .github/workflows/ci.yml` matches and `grep -rn 'contents: write' .github/workflows/ci.yml` is empty (write lives only in the release workflow).
- `grep -h -oE 'v2\.[0-9]+\.[0-9]+' .github/workflows/ci.yml Makefile | sort -u | wc -l` prints 1: one golangci-lint version everywhere.
- `test -f .github/dependabot.yml` succeeds and the file covers both `gomod` and `github-actions` ecosystems.
- Release scaffold, when in scope: `grep -n 'fetch-depth: 0' .github/workflows/release.yml` matches, and `goreleaser check` passes on the committed config (or its absence is reported).
- Placeholder leak check on every copied template: `grep -nE 'PROJECT|USER/|delete this' .goreleaser.yaml .github/workflows/*.yml` is empty.

## Service-backed integration jobs

When tests need a database, use GitHub Actions `services:` with the **same**
healthcheck options as your compose file (`--health-cmd`, `--health-interval 5s`,
`--health-retries 10`), pass DSNs via `env:`, and run the same `make integration`
target locally and in CI. See `shell-gates.md`.

## Dependency-free convention gates

Enforce Conventional Commits, per-module LICENSE presence, and any code-absence
invariants as pure-shell jobs that emit `::error::` annotations: no new
dependency, so a pure-Go repo stays pure-Go. `commitlint` ships in `ci.yml`;
`license` and `public-tree` are in `shell-gates.md`.
