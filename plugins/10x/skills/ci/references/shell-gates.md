# CI Shell Gates & Patterns

Pure-shell gates beyond `ci.yml`; emit `::error::` / `::error file=::` annotations.

## License gate (multi-module)

Every `go.mod` directory must contain `LICENSE`.

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
          # dirname also handles the root module.
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

Gate forbidden public-tree vocabulary; exclude generated files and the defining workflow.

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

Reference the invariant's ADR in a comment.

## Service-backed integration jobs

`ci.yml` includes Postgres. Match Compose health command/options exactly (standard datastore: interval 5s, timeout 3s, retries 10). Map ports to localhost, pass DSNs through step `env:`; the same `make integration` reads CI env or local `.env`. Each additional service gets a separate entry:

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

Prefer audit -> cover. Without those targets, use this inline gate; keep 80 equal to `COVER_MIN` in `../../makefile/references/makefile-go.md`.

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

For exercised production packages add `-coverpkg=./internal/...,./helpers/...`; publish the HTML report:

```yaml
      - name: Publish coverage report
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: coverage-report
          path: coverage.html
```

## go.work multi-module release (goreleaser alternative)

For multi-module workspaces, replace single-module goreleaser with dependency-ordered module tags:

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

Subdirectory module versions require path-prefixed tags (`server/v1.2.0`).
