# CI Shell Gates & Patterns

Extra CI jobs and patterns beyond `ci.yml`. All are dependency-free (pure shell)
so a pure-Go repo gains no new toolchain, and all emit `::error::` /
`::error file=::` annotations so failures surface inline on the PR.

## License gate (multi-module)

Every Go module (each `go.mod` directory) must ship its own `LICENSE` so
`pkg.go.dev` and the go tooling resolve a license per module. Catches the drift
where a new `example/` or `client/` module is added without one.

```yaml
  license:
    name: license
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - name: Every module ships a LICENSE file
        run: |
          set -euo pipefail
          fail=0
          # dirname handles the root module (./go.mod -> .) correctly; a sed strip
          # would leave it as "go.mod" and false-fail a single-module repo.
          for gm in $(find . -name go.mod -not -path './vendor/*'); do
            d=$(dirname "$gm")
            if [ ! -f "$d/LICENSE" ]; then
              echo "::error file=$d::module '$d' has no LICENSE file"
              fail=1
            fi
          done
          exit $fail
```

## Public-tree gate (code-absence invariant)

When an open-core or public tree must **not** contain certain vocabulary
(hosted-service surfaces, internal codenames, secrets patterns), grep for it in
CI so a re-introduction fails the build instead of slipping through review. Skip
generated files and the workflow itself (which necessarily names the terms).

```yaml
  public-tree:
    name: public tree hygiene
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - name: No forbidden vocabulary in the public tree
        run: |
          set -euo pipefail
          pattern='stripe|billing|internal_codename'
          if git grep -nEi "$pattern" -- '*.go' '*.md' '*.sql' '*.yml' '*.yaml' ':!*.pb.go' ':!.github/'; then
            echo "::error::forbidden vocabulary found in the public tree: see matches above"
            exit 1
          fi
          echo "public tree clean"
```

Anchor the invariant to an ADR in the comment so a future reader knows why the
gate exists.

## Service-backed integration jobs

`ci.yml` includes a Postgres example. The rules:

- Use the **same** healthcheck options as your compose file so CI and local
  behave identically: `--health-cmd`, `--health-interval 5s`, `--health-timeout
  3s`, `--health-retries 10`. GitHub holds the job until the service is healthy.
- Map the container port to localhost and pass DSNs via `env:` on the step.
- Run the **same `make integration` target** locally and in CI: the target
  reads the DSNs from env (CI sets localhost) or derives them from `.env`
  (local). One command, one code path.

Multiple services (e.g. Postgres + ClickHouse) each get their own `services:`
entry with matching health options:

```yaml
    services:
      clickhouse:
        image: clickhouse/clickhouse-server:24.8
        ports: ["9000:9000", "8123:8123"]
        options: >-
          --health-cmd "wget --no-verbose --tries=1 --spider http://localhost:8123/ping || exit 1"
          --health-interval 5s --health-timeout 3s --health-retries 10
```

## Inline coverage-gate fallback

`ci.yml` gates coverage through `make audit` (which depends on `make cover`). If
a repo has no such target, gate inline in the test job. The `80` below is the
`COVER_MIN` default from `../../makefile/references/makefile-go.md`, restated
here only because there is no Makefile to read it from; keep the two equal, and
prefer the `make cover` path so the number lives in one place.

```yaml
      - name: Test (race + coverage)
        run: go test -race -covermode=atomic -coverprofile=coverage.out ./...
      - name: Coverage gate (>= 80%)
        run: |
          total=$(go tool cover -func=coverage.out | awk '/^total:/ {gsub(/%/,"",$3); print $3}')
          echo "total coverage: ${total}%"
          awk "BEGIN{ exit !(${total}+0 >= 80) }" \
            || { echo "FAIL: coverage ${total}% is below the 80% gate"; exit 1; }
```

To measure the production code a test *exercises* (not just the package it lives
in), add `-coverpkg=./internal/...,./helpers/...`. Publish the HTML report as an
artifact for inspection:

```yaml
      - name: Publish coverage report
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: coverage-report
          path: coverage.html
```

## go.work multi-module release (goreleaser alternative)

goreleaser targets a single module. For a workspace that publishes several
tagged modules (`proto`, `client`, `server`), release with a Makefile target
that tags each module path in dependency order instead:

```makefile
MODULES ?= proto client server   # dependency order

## release: tag every module at VERSION in dependency order (usage: make release VERSION=v1.2.0)
release: confirm
	@for m in $(MODULES); do \
		tag="$$m/$(VERSION)"; \
		echo "tagging $$tag"; \
		git tag -a "$$tag" -m "$$m $(VERSION)" || exit 1; \
	done
	git push --tags
```

Path-prefixed tags (`server/v1.2.0`) are how the Go module proxy resolves a
version for a module in a subdirectory.
