---
name: ci
description: 'GitHub Actions CI/CD best practices for Go projects. Use when creating or reviewing CI workflows, release automation (goreleaser), dependabot, coverage gates, matrix builds, or service-backed integration jobs; especially when a repo has Makefile audit/build/test targets but no .github/workflows to run them. Not for auditing an existing repo''s CI against the 10x standard: the `conform` skill runs those checks.'
---
# 10x CI

CI must call the same Makefile targets as local development. Add workflows when quality targets exist without CI.

## Reference

| Resource | Purpose |
|----------|---------|
| `./references/ci.yml` | Matrix, lint/vuln, commitlint; optional image/SAST/integration jobs |
| `./references/release.yml`, `./references/goreleaser.yaml` | Tag release, checksums, changelog, SBOM/signing |
| `./references/release-python.yml` | Python tag build + PyPI Trusted Publishing (`release.workflow`) |
| `./references/dependabot.yml` | Weekly gomod + github-actions updates |
| `./references/shell-gates.md` | Load for shell gates, service tests, coverage fallback, workspace releases |
| `../_shared/references/versions.md` | Read action/tool pins before scaffolding |

## MUST DO

- Top-level least privilege: CI `contents: read`; release alone gets `contents: write`.
- Trigger `push` to `main` and `pull_request`; concurrency `ci-${{ github.ref }}`, `cancel-in-progress: true`.
- Go matrix: `fail-fast: false`, `go: ["<go.mod floor>", "stable"]`; release builds use stable. Use `actions/setup-go` caching; outside a matrix prefer `go-version-file: go.mod`.
- Call `make build`, `make test`, `make audit`; audit depends on cover and fails below `COVER_MIN`. Without that target, use the reference's inline awk gate.
- Copy action/tool pins from the shared versions reference at scaffold time, never duplicate them in comments. CI golangci-lint must match Makefile `tools` and `.golangci.yml` schema.
- Build every build-tag variant; ship Dependabot for `gomod` and `github-actions`.
- Tags `v*` trigger goreleaser: static, `-trimpath`, stamped binaries for linux/darwin/windows × amd64/arm64. Stamp `Version` as `v{{ .Version }}`; archive names stay unprefixed.
- For `sboms:`/`signs:`, install `anchore/sbom-action/download-syft` and `sigstore/cosign-installer`; grant `id-token: write`.
- Cosign signing uses `--bundle=${signature}` and `${artifact}.sigstore.json`, never `--output-signature`/`--output-certificate` (cosign 3 bundle contract).

## MUST NOT

- Reimplement existing Makefile targets in YAML, grant CI write access, or omit CI for existing quality targets.
- Omit `fetch-depth: 0` on release checkout.

## Done when

- `actionlint` clean; skip only if unavailable and report it.
- Verify CI invokes build/test/audit, has `contents: read` and no write grants; CI/Makefile have one golangci-lint pin.
- `.github/dependabot.yml` covers both ecosystems.
- Release in scope: full-history checkout and `goreleaser check` pass (report missing tool).
- `grep -nE 'PROJECT|USER/|delete this' .goreleaser.yaml .github/workflows/*.yml` is empty after copying templates.

## Service-backed integration jobs

For database tests, use `services:` with healthcheck options exactly matching Compose and the same local/CI `make integration` target. Load `shell-gates.md` for values, ports/DSNs and multi-service wiring.

## Dependency-free convention gates

Enforce Conventional Commits, per-module LICENSE and code-absence invariants with pure shell and `::error::` annotations. Load `ci.yml` for commitlint; `shell-gates.md` for license/public-tree.
