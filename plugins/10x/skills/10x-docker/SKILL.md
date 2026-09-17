---
name: 10x-docker
description: 'Docker and docker-compose best practices. Use for any Docker task: Dockerfiles (multi-stage builds, alpine, non-root), docker compose services (Go API, frontend, MariaDB, Oracle), healthchecks, volumes, networks, and K8S-compatible configurations. Not for running a large multi-file containerization work-package end to end: dispatch docker-agent, which applies this skill.'
---
# 10x Docker 

## Dockerfile

For Go API please follow the recommendations in ./references/go-api-dockerfile.md
For Frontend applications follow the recommendations in ./references/frontend-dockerfile.md
Pair every Dockerfile with an allowlist `.dockerignore`: see ./references/dockerignore.md

### Dockerfile Standards (MUST)

- Pin the syntax and use BuildKit: `# syntax=docker/dockerfile:1.7`, and cache the Go caches with `RUN --mount=type=cache,target=/go/pkg/mod` and `--mount=type=cache,target=/root/.cache/go-build`.
- Build a static, reproducible, stripped binary: `CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w ..."`.
- **Copy only the packages the binary compiles from: never `COPY . .`.** Copy `go.mod`/`go.sum` and `go mod download` *before* the source so a code change does not re-download modules. Keep the `COPY` list in sync with `.dockerignore`.
- Copy runtime assets (templates, locales) from the build context in the runtime stage, not through the builder stage, so editing them rebuilds only small layers.
- Run as a non-root user with a numeric UID (`USER 1001`) for K8S `runAsNonRoot`.
- Add a `HEALTHCHECK` instruction (self-describing image), `EXPOSE` the port, and OCI `LABEL`s (`org.opencontainers.image.source`/`.licenses`/`.title`).
- Explicit image tags, never `latest`. Do not bake a local `TZ` into a shared image.

### Dockerfile Performance

1. **Layer Caching:**
   - Copy dependency files first (go.mod, package.json)
   - Run dependency download before copying source
   - Order COPY commands from least to most frequently changed

2. **Build Optimization:**
   - Use multi-stage builds
   - Minimize number of layers
   - Combine RUN commands where appropriate

3. **Development Speed:**
   - Provide Dockerfile_localbuild for fast iteration
   - Use volume mounts for live reload
   - Implement proper healthchecks

### Done when (Dockerfile)

- `docker build .` completes, and `docker inspect -f '{{.Config.User}}' <image>` prints a numeric UID (non-root survives into the final stage).
- `grep -n 'syntax=docker/dockerfile' Dockerfile` and `grep -n 'HEALTHCHECK' Dockerfile` both match.
- `grep -n 'COPY \. \.' Dockerfile` and `grep -n ':latest' Dockerfile` are both empty.
- `test -f .dockerignore` succeeds and the file is an allowlist (starts by ignoring `*`).

## Docker-compose.yml

- Omit the `version` field (obsolete in Compose v2; it triggers a warning)
- Use `services:` as top-level key

### Per-Environment Files (MUST)

Split environments by file, not `profiles`: a neutral base `docker-compose.yml`
plus thin overlays merged with `-f`. See ./references/docker-compose-environments.md
(and the `10x-makefile` skill's `makefile-compose.md` for the targets that drive them).

- The **base** defines services, images, healthchecks, `depends_on`, and named volumes: but **no host ports, no `container_name`, no environment routing**. Overlays (`docker-compose.local.yml` / `.prod.yml` / `.test.yml`) add those.
- **Healthcheck on every service** (app: HTTP spider ~30s; datastore: native probe like `pg_isready` ~5s, retries 5-10).
- **`depends_on` always uses `condition: service_healthy`**: never a bare `depends_on` (that waits for start, not readiness).
- Address services by **compose service name**, not host ports. Named volumes for data; read-only (`:ro`) bind mount for init scripts.
- **Restart policy per env**: base `unless-stopped`, prod `always`, test `"no"`. Run the test stack under its own `-p` project with `.env.test`.
- Add **resource controls** (`ulimits`, `deploy.resources.limits`) for services that can run away.
- **Configurable host ports, never hardcoded**: publish as `${SOME_PORT:-<default>}` and bind local datastore ports to `127.0.0.1`. A stack must not require editing the file to move a port.
- **Front prod with the host's preconfigured reverse proxy, not a bundled one**: when the target host already runs a shared Traefik/nginx-proxy on an external `proxy` network, the prod overlay joins that network and routes via labels. Never ship a per-app proxy that binds 80/443. When a service is on more than one network, set `traefik.docker.network=<proxy-net>` or routing is non-deterministic. Route apex and www as **two routers to one service** (canonical www at `priority=1` plus a `-bare` apex router) off a single `APEX_DOMAIN` var, not one `||` rule; gate `make up` on a `preflight` that rejects an empty/default domain (see `10x-makefile`).
- **`.env` is the single config source, auto-loaded, no `env_file:` directive**: the user derives `.env` from a committed `env.sample`; Compose auto-loads `./.env` for `${VAR}` interpolation. Deliver config via an explicit `environment:` map (each container gets only what it reads), not `env_file:` (which dumps the whole file in). Prod keeps `.env` beside the compose files at mode 0600; test swaps it with `--env-file .env.test`. Because `docker compose` reads `.env` but `make` does not, any Makefile guard on those vars must `-include .env` and `export`, or it sees empty values while compose sees the real ones.

### Done when (compose)

- `docker compose -f docker-compose.yml -f docker-compose.<env>.yml config -q` exits 0 for every overlay touched.
- `grep -n '^version:' docker-compose*.yml` is empty.
- In the rendered `docker compose ... config` output, every `depends_on` entry shows `condition: service_healthy`, and the number of `healthcheck:` blocks equals `docker compose ... config --services | wc -l`.
- `grep -nE '"[0-9]+:[0-9]+"' docker-compose*.yml` is empty: every published host port is a `${VAR:-default}`.
- `grep -n 'env_file:' docker-compose*.yml` is empty; config flows through `environment:` maps from the auto-loaded `.env`.

### Standard Service Patterns

For MariaDB service read ./references/mariadb-docker-compose-service.md
For Oracle service read ./references/oracle-docker-compose-service.md
For Go API service read ./references/go-api-docker-compose-service.md
For Frontend service read ./references/frontend-docker-compose-service.md

### Verification and Troubleshooting

Before completing any task, run through `./references/verification-checklist.md`.
For build/runtime/permission issues, consult `./references/troubleshooting.md`.

### Volumes

**Common Volume Patterns:**
1. **Init Scripts:** `./conf/docker/initdb:/docker-entrypoint-initdb.d`
2. **Configuration:** `./conf/docker/mariadb.cnf:/etc/mysql/mariadb.cnf`
3. **Logs:** `/tmp/logs:/tmp/logs`
4. **Runtime Config:** `./conf/docker/environment.json:/usr/share/nginx/html/assets/environments/environment.json`

Do **not** bind-mount `env.sample` (or `.env`) into the container as a config file. App config comes from the auto-loaded `.env` via an `environment:` map (see Per-Environment Files), not a mounted file.

### Ports

**Standard Port Mappings:**
- Application APIs: `8080:8080`
- MariaDB: `23306:3306` (non-conflicting external port)
- Oracle: `1521:1521`, `5500:5500`
- PostgreSQL: `25432:5432`

### Networks
- Use default network for simple setups
- Explicit networks only when needed for isolation

## Environment Variables

**Naming Convention:**
- UPPERCASE with underscores
- Prefixed with component name (e.g., `MARIADB_`, `ORACLE_`)
- Use `.env` files for sensitive data (not committed)
- Use `env.sample` as template

**Common Variables:**
- `MARIADB_ROOT_PASSWORD`, `MARIADB_DATABASE`, `MARIADB_USER`, `MARIADB_PASSWORD`
- `TZ` (set per deployment, e.g. `TZ=UTC`; never bake a local timezone into a shared image)
- `DOCKERFILE` for build variant selection

## Best Practices

### Security

1. **Non-root User:**
   - Always run as non-root (USER 1001)
   - Create dedicated user/group
   - Set proper permissions for K8S compatibility

2. **Minimal Images:**
   - Use alpine or slim variants when possible
   - Multi-stage builds to reduce final image size

3. **Secrets Management:**
   - Never commit passwords in docker-compose.yml
   - Use environment variables
   - Provide env.sample templates
   - Use Docker secrets for production


### Maintainability

1. **Naming:**
   - Container names: `project-component` (e.g., `persons-api`, `persons-db`)
   - Image names: match container names
   - Image tag: use explicit version number instead of 'latest'
   - Service names: descriptive and consistent

2. **Documentation:**
   - Comment architecture-specific choices
   - Document environment variables
   - Provide usage examples in README

3. **Variants:**
   - `Dockerfile` - Production with multi-stage build
   - `Dockerfile_localbuild` - Local development (pre-built binary)
   - `Dockerfile_test` - Testing environment
   - `docker-compose.yml` - Neutral base (no host ports / container_name / routing)
   - `docker-compose.local.yml` - Local dev overlay (published ports, dev env)
   - `docker-compose.prod.yml` - Production overlay (internal DBs, restart always, proxy)
   - `docker-compose.test.yml` - Test overlay (`.env.test`, isolated ports, restart "no")

