# Pinned Tool & Action Versions (single source of truth)

This file is the one place the 10x Go/CI/Makefile skills agree on versions.
`lang-go`, `makefile`, and `ci` all point here so a `make tools`
target, a `.golangci.yml`, and a CI workflow never pin three different
golangci-lint versions.

These are a moving target. Treat the values below as the baseline to scaffold
with, and bump them in one edit here rather than per-skill. When bumping, keep
the CI action `version:` field, the Makefile `tools` target, and any committed
config identical.

## Go toolchain

| Field | Value | Rule |
|-------|-------|------|
| `go` (go.mod) | project floor, e.g. `1.25.x` | The minimum version a module *consumer* must have. Set to the oldest release you still support; raise deliberately. |
| `toolchain` (go.mod) | latest patch, e.g. `go1.26.4` | The toolchain used to *build/test*. Track the latest patch for stdlib security fixes. May legitimately be newer than the `go` line. |

The `go` and `toolchain` lines differ on purpose: the first is a compatibility
floor for people importing your module, the second is the compiler you build
with. Document the gap in-repo if a reviewer might mistake it for a mistake.

## Go quality tools (pin in the Makefile `tools` target AND the CI `lint` job)

| Tool | Version | Install |
|------|---------|---------|
| golangci-lint | `v2.13.2` | `go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.13.2` |
| govulncheck | `v1.1.4` | `go install golang.org/x/vuln/cmd/govulncheck@v1.1.4` |

The golangci-lint version pinned here MUST equal the `version:` field passed to
`golangci/golangci-lint-action` in CI. Config format is golangci-lint schema
`version: "2"`.

## GitHub Actions (pin in every workflow)

| Action | Version | Notes |
|--------|---------|-------|
| `actions/checkout` | `v7` | `fetch-depth: 0` in release workflows (needs tags/history for changelogs). |
| `actions/setup-go` | `v7` | Prefer `go-version-file: go.mod`; use `check-latest: true` with a matrix. Handles module + build caching. v7.0.0 is an ESM/dependency migration: no input or behavior change from v6. |
| `golangci/golangci-lint-action` | `v8` | Set `version: v2.13.2` to match the pin above. |
| `goreleaser/goreleaser-action` | `v6` | `version: "~> v2"`, `args: release --clean`. Release workflow only. |
| `sigstore/cosign-installer` | `v3` | Release workflow only; needed when `goreleaser.yaml` has `signs:` (cosign keyless). |
| `anchore/sbom-action/download-syft` | `v0` | Release workflow only; needed when `goreleaser.yaml` has `sboms:` (syft). |
| `actions/upload-artifact` | `v4` | Coverage/report artifacts; use `if: always()`. |
| `docker/setup-buildx-action` | `v3` | Image build jobs only. Pinned to the version in production use; upstream is already on v4. |
| `docker/build-push-action` | `v6` | Image build jobs only; pair with buildx above. Pinned to the version in production use; upstream is already on v7. |
| `aquasecurity/trivy-action` | `v0.36.0` | Image scan. The tag IS `v`-prefixed: an unprefixed `0.x.y` fails at "Set up job" with `unable to find version`, before any step runs. |
| `github/codeql-action/*` | `v3` | SAST. `init` + `autobuild` + `analyze` must all be the same major. Needs `security-events: write`. |

## Reconciled drift (why these values)

Observed across the reference repos before this baseline was set:

- `actions/checkout`: v4 and v7 both in use → **v7**.
- `actions/setup-go`: v5 and v6 both in use → **v7** (v6 was the reconciled
  value until v7.0.0 shipped; v7 adds no inputs, so the bump is free).
- `golangci/golangci-lint-action`: v7 and v8 both in use → **v8**.
- golangci-lint: v2.11.3 and v2.12.2 both in use → **v2.13.2** (v2.12.2 was the
  reconciled value; bumped to v2.13.2 to match the current upstream release).
- govulncheck: v1.1.4 everywhere → **v1.1.4** (no drift).
- `aquasecurity/trivy-action`: absent from this table while `standard.yml`
  graded repos on having a scan, so scan jobs were hand-written and one
  invented `0.28.0`, a tag that does not exist → **v0.36.0**, pinned here and
  templated in `ci/references/ci.yml` so nobody has to guess again.

Pick the newest observed and move every repo to it; do not leave two workflows
on different majors.
