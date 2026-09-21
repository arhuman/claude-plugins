# .dockerignore: allowlist pattern

Deny everything, then re-include only the inputs the Dockerfile actually
`COPY`s. This is the counterpart to the Dockerfile's explicit-package `COPY`
list: anything new (a data dir, a dump, a tool, a secret) is excluded by default
instead of silently bloating the image or busting the build cache.

```dockerignore
# 1. Exclude everything.
*

# 2. Re-include exactly what the Dockerfile COPYs (keep in sync with it).
!go.mod
!go.sum
!cmd/api
!internal
# Runtime assets, if the image serves them:
# !webroot
# !locales

# 3. Re-exclude test files last: `go build` ignores them and they only bust
#    the cache and enlarge the context.
**/*_test.go
```

Rules:
- The re-include list must match the Dockerfile's `COPY` lines one-for-one. When
  you add a `COPY`, add a `!` entry here in the same change.
- Keep secrets and local state out by construction: because the first line
  excludes `*`, a stray `.env`, `coverage.out`, or `tmp/` never reaches the
  daemon even if you forget to name it.
- Put the test-file re-exclusion **after** the re-includes; order matters in
  `.dockerignore` (last match wins).
