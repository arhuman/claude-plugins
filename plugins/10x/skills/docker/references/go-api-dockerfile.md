# Dockerfile for Go API

Image tags verified 2026-07. Multi-stage alpine build with BuildKit cache
mounts, a static `-trimpath` binary, a non-root user, a `HEALTHCHECK`, and OCI
labels.

**Production Dockerfile (multi-stage):**
```dockerfile
# syntax=docker/dockerfile:1.7
# The syntax line enables BuildKit features (cache mounts below). Build with
# DOCKER_BUILDKIT=1 (default in modern Docker / `docker buildx`).

# ---- build stage ----
FROM golang:1.26-alpine AS builder
# git for VCS-stamped builds; ca-certificates/tzdata so `go build` and any
# module fetch over HTTPS work.
RUN apk add --no-cache git ca-certificates tzdata
WORKDIR /build

# Dependencies before source: a code change must not re-run `go mod download`.
# The cache mount persists /go/pkg/mod across rebuilds.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy ONLY the packages the binary compiles from: never `COPY . .`. Listing
# packages explicitly keeps runtime assets, docs, tests, and tooling out of the
# builder, so a change under webroot/ or docs/ does not invalidate this layer or
# the cached compile below. Keep this list in sync with .dockerignore.
COPY cmd/api ./cmd/api
COPY internal ./internal

# Version metadata (optional): pass with --build-arg to match the Makefile's
# ldflags (VERSION_PKG). Leave unset for a plain build.
ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_DATE=unknown

# Mounting GOCACHE + the module cache turns a cold ~50s rebuild into a hot one
# that only recompiles changed packages. CGO_ENABLED=0 => static binary;
# -trimpath => reproducible paths; -s -w => strip debug info.
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=linux \
    go build -trimpath \
      -ldflags="-s -w \
        -X main.Version=${VERSION} \
        -X main.GitCommit=${COMMIT} \
        -X main.BuildDate=${BUILD_DATE}" \
      -o /out/server ./cmd/api

# ---- runtime stage ----
FROM alpine:3.19
# ca-certificates for outbound TLS, tzdata for time zones, wget for the healthcheck.
RUN apk add --no-cache ca-certificates tzdata wget

# Non-root user. A numeric UID lets Kubernetes `runAsNonRoot` verify it without
# a lookup. Group 0 + g=u perms keep it OpenShift-compatible.
RUN addgroup -S app && adduser -S -u 1001 -G app app
WORKDIR /app

COPY --from=builder /out/server ./server
# Runtime assets come straight from the build context (not via the builder
# stage) so editing a template rebuilds only these small layers, never the Go
# compile above. Uncomment what the app serves:
# COPY webroot ./webroot
# COPY locales ./locales
RUN chown -R 1001:0 /app && chmod -R g=u /app

USER 1001
# Do not bake a local timezone into a shared image; override per deployment.
ENV TZ=UTC
EXPOSE 8080

# Container-level liveness. Compose/K8S can also define their own; this makes the
# image self-describing. Adjust the path to the real liveness route.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q --spider http://localhost:8080/healthz || exit 1

# OCI labels make the image traceable back to its source and license. Prefer
# passing dynamic values via --build-arg/--label in CI; static ones can live here.
LABEL org.opencontainers.image.source="https://github.com/USER/PROJECT" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="PROJECT-api"

CMD ["./server"]
```

Notes:
- The runtime stage is `alpine:3.19`, not a `golang` image: the static binary needs no toolchain, and alpine keeps `ca-certificates`/`tzdata`/a shell for the healthcheck while staying small.
- `wget` exists only to serve the healthcheck; drop it (and the `HEALTHCHECK`) if you probe differently, e.g. a `grpc_health_probe` or a built-in `--health` subcommand.
- Pair with an allowlist `.dockerignore` (`./dockerignore.md`) so the explicit `COPY` list is the *only* thing that enters the build context.
