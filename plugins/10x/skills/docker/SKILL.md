---
name: docker
description: 'Docker and docker-compose best practices. Use for Dockerfiles, multi-stage/non-root builds, Compose services, healthchecks, volumes, networks, and K8S permissions. For end-to-end multi-file containerization, dispatch docker-agent, which applies this skill.'
---
# 10x Docker

## Dockerfile

Load `references/go-api-dockerfile.md` for Go, `references/frontend-dockerfile.md` for frontend, and `references/dockerignore.md` for every build context.

### Dockerfile Standards (MUST)

- BuildKit syntax `# syntax=docker/dockerfile:1.7`; Go cache mounts at `/go/pkg/mod` and `/root/.cache/go-build`.
- Static, reproducible, stripped Go binary: `CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w ..."`.
- Explicit package `COPY`, never `COPY . .`; keep `.dockerignore` allowlist synchronized. Copy manifests and download dependencies before source. Runtime assets come directly from context into the runtime stage.
- Numeric non-root `USER 1001`; minimal alpine/slim runtime, explicit tags, never `latest` or baked-in local timezone.
- Include `HEALTHCHECK`, `EXPOSE`, OCI source/licenses/title labels. Alternative probes: see Go reference.

### Dockerfile Performance

Multi-stage builds; order copies least-to-most changed; combine related `RUN` steps. Local iteration uses a prebuilt-binary `Dockerfile_localbuild` and source mounts for live reload.

### Done when (Dockerfile)

- `docker build .` succeeds; final `docker inspect -f '{{.Config.User}}' <image>` is numeric/non-root.
- Syntax directive and healthcheck present; no `COPY . .` or `:latest`; `.dockerignore` starts with `*`.

## Docker-compose.yml

Use Compose v2 `services:`; omit obsolete `version:`.

### Per-Environment Files (MUST)

Load `references/docker-compose-environments.md` for every Compose change. Use base + local/prod/test overlays with `-f`, not profiles. For Makefile drivers load `../makefile/references/makefile-compose.md`.

- Base owns services/images, healthchecks, healthy dependencies, named data volumes; overlays own host ports, container names and routing.
- Every service has a healthcheck: app HTTP ~30s, datastore native probe ~5s with 5-10 retries. Every dependency uses `condition: service_healthy`.
- Containers connect by service name. Init-script mounts are read-only. Restart: base `unless-stopped`, prod `always`, test `"no"`; tests use separate `-p` project and `.env.test`.
- Published ports use `${VAR:-default}`; local datastores bind loopback. Fixed disposable test ports are the explicit exception.
- Prod uses the host's shared proxy, never a per-app proxy binding 80/443. Load environment reference for network pinning and apex/www routers; Makefile reference owns domain/secret preflight.
- Config: committed `env.sample` -> uncommitted, auto-loaded `.env` -> explicit `environment:` maps; no `env_file:`. Environment reference owns prod 0600, test override and Makefile include/export rules.
- Cap runaway services with `ulimits` and `deploy.resources.limits`.

### Done when (compose)

- `docker compose -f docker-compose.yml -f docker-compose.<env>.yml config -q` passes for each touched overlay.
- Rendered config has a healthcheck per service and healthy conditions on every dependency.
- No obsolete `version:`, `env_file:`, or bare published port outside the test overlay.

### Standard Service Patterns

Load the matching reference: `references/mariadb-docker-compose-service.md`, `references/oracle-docker-compose-service.md`, `references/go-api-docker-compose-service.md`, or `references/frontend-docker-compose-service.md`.

### Verification and Troubleshooting

Before completion read `references/verification-checklist.md`; on build/runtime/permission failures read `references/troubleshooting.md`.

### Volumes

Use service-reference mount paths for init scripts, database config and frontend `environment.json`; logs may use `/tmp/logs:/tmp/logs`. Never mount `.env` or `env.sample` as application config.

### Ports

Host defaults (container ports stay fixed):

- API `${API_PORT:-8080}:8080`
- MariaDB `127.0.0.1:${DB_PORT:-23306}:3306`
- PostgreSQL `127.0.0.1:${DB_PORT:-25432}:5432`
- Oracle `${ORACLE_PORT:-1521}:1521`, `${ORACLE_EM_PORT:-5500}:5500`

### Networks

Default network for simple stacks; explicit networks for isolation/proxy access.

## Environment Variables

UPPERCASE_UNDERSCORES with component prefixes (`MARIADB_`, `ORACLE_`). Document in `env.sample`; secrets stay uncommitted. `TZ` is deployment-specific, default UTC; `DOCKERFILE` selects the build variant. Service references specify database variables.

## Best Practices

### Security

Go reference owns OpenShift `chgrp 0` / `chmod g=u`. Never commit passwords in Dockerfiles/Compose. Prefer production Docker secrets for values not required in the process environment.

### Maintainability

- Names: `project-component` containers and matching images; descriptive, consistent service names.
- Document variables, architecture-specific choices and README usage.
- Variants: production multi-stage `Dockerfile`, prebuilt local `Dockerfile_localbuild`, testing `Dockerfile_test`; Compose base + `.local.yml`, `.prod.yml`, `.test.yml` overlays as above.
