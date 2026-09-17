# Docker Compose: per-environment files

Split environments by **file**, not by `profiles`. A neutral base plus thin
overlays merged with `-f` keeps each environment's differences small and
explicit. The `10x-makefile` skill's `makefile-compose.md` provides the targets
that drive these files.

## Base: `docker-compose.yml` (neutral)

The base defines services, images, healthchecks, `depends_on`, and named volumes
: but **no host ports, no `container_name`, and no environment-specific
routing**. Those belong to overlays, so the base can be composed into any
environment without editing.

Config comes from a single `.env` file that the user derives from a committed
`env.sample`. Compose loads `./.env` **automatically** for `${VAR}` interpolation
: so there is **no `env_file:` directive**. Containers receive exactly the
variables they need through an explicit `environment:` map that interpolates from
that auto-loaded `.env`. This keeps the container's environment intentional
(only what the service reads) rather than dumping the whole `.env` into it.

```yaml
services:
  api:
    build:
      context: .
      dockerfile: ${DOCKERFILE:-Dockerfile}
    # Explicit, interpolated from the auto-loaded ./.env. No env_file: directive.
    environment:
      APP_DB_DSN: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}?sslmode=disable
      APP_JWT_SECRET: ${JWT_SECRET}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/healthz"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    depends_on:
      db:
        condition: service_healthy   # never a bare depends_on

  db:
    image: postgres:17
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./config/docker/initdb:/docker-entrypoint-initdb.d:ro   # runs once on empty data dir
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  postgres-data:
```

## Overlays

Merge with `docker compose -f docker-compose.yml -f docker-compose.<env>.yml ...`
(put the invocation in a header comment of each overlay).

**`docker-compose.local.yml`**: publish ports (configurable, default sane), dev env:
```yaml
services:
  api:
    container_name: app-api
    # Configurable host port with a default: never hardcode. Lets a second
    # stack or a host process coexist without editing the file.
    ports: ["${API_PORT:-8080}:8080"]
    environment:
      GO_ENV: development
  db:
    container_name: app-db
    # Bind to loopback and offset from 5432 (the skill's standard datastore
    # mapping is 25432:5432) to avoid clashing with another project's Postgres.
    ports: ["127.0.0.1:${DB_PORT:-25432}:5432"]
```

**`docker-compose.prod.yml`**: front with the host's **preconfigured** reverse proxy, not a
bundled one. On a VPS that already runs a shared Traefik watching an external
`proxy` network, the app **joins that network and declares routing via labels**
instead of shipping its own Traefik and binding 80/443. This avoids a
per-app proxy, port collisions, and duplicated TLS config. Secrets come from
`.env` beside the compose files; the image is built locally from the Dockerfile
(no registry in the deploy path unless you want one).

```yaml
services:
  api:
    container_name: app-api
    # Secrets come from the auto-loaded .env (mode 0600, next to the compose
    # files) via the base's environment: map. No env_file: directive.
    restart: always
    networks:
      - default               # reach db on the compose network
      - proxy                 # be reachable by the host Traefik
    labels:
      - traefik.enable=true
      # Two routers to one service: a canonical www router (priority 1) and a
      # bare-apex router, both pointing at the same service. Prefer this over a
      # single Host(`a`) || Host(`www.a`) rule: splitting the hostnames lets you
      # later attach a redirect or per-host middleware (an apex->www 301, a
      # per-host rate limit) to just one of them without re-splitting the rule.
      # APEX_DOMAIN comes from .env (document it in env.sample).
      - traefik.http.routers.app.service=app
      - traefik.http.routers.app.rule=Host(`www.${APEX_DOMAIN}`)
      - traefik.http.routers.app.entrypoints=websecure
      - traefik.http.routers.app.tls.certresolver=le
      - traefik.http.routers.app.priority=1
      - traefik.http.routers.app-bare.service=app
      - traefik.http.routers.app-bare.rule=Host(`${APEX_DOMAIN}`)
      - traefik.http.routers.app-bare.entrypoints=websecure
      - traefik.http.routers.app-bare.tls.certresolver=le
      - traefik.http.services.app.loadbalancer.server.port=8080
      # REQUIRED when the service is on >1 network: pin which one Traefik routes
      # over, or it guesses and routing breaks intermittently after a redeploy.
      - traefik.docker.network=proxy
      # Optional per-route middleware, e.g. a per-IP rate limit on login:
      # - traefik.http.middlewares.app-login.ratelimit.average=5
      # - traefik.http.routers.app-login.rule=Host(`www.${APEX_DOMAIN}`) && Path(`/api/v1/login`)
      # - traefik.http.routers.app-login.middlewares=app-login
    # No published host ports: the app is reachable only through Traefik.
  db:
    container_name: app-db
    restart: always           # no published ports: reachable only on the compose network

networks:
  proxy:
    external: true            # created and watched by the host Traefik, not this stack
```

**`docker-compose.test.yml`**: isolated, disposable, namespaced with `-p`.
Run it with `--env-file .env.test` (see `makefile-compose.md`) so the same
`environment:` interpolation resolves from the test env instead of `.env`:
```yaml
services:
  api:
    ports: ["3001:8080"]
    restart: "no"
  db:
    ports: ["5433:5432"]
    restart: "no"
    volumes:
      # Seeded fixtures instead of the local init scripts.
      - ./config/docker/initdb-test:/docker-entrypoint-initdb.d:ro
```
Run the test stack under its own project name so its network and volumes are
namespaced and can run alongside local: `docker compose -p app-test -f
docker-compose.yml -f docker-compose.test.yml up -d`.

## Rules

- **Healthcheck on every service.** App: HTTP spider, `interval 30s`. Datastores:
  native probe (`pg_isready`, `wget /ping`), tight `interval 5s`, `retries 5-10`.
- **`depends_on: { <svc>: { condition: service_healthy } }`**: never a bare
  `depends_on`, which only waits for container start, not readiness.
- **Address services by compose service name** (`db:5432`), not host ports.
  Host ports are for the human on the outside; containers talk over the network.
- **Named volumes** for data; **read-only** bind mount for init scripts (`:ro`),
  which run once in filename order on an empty data dir.
- **Restart policy per env**: base `unless-stopped`, prod `always`, test `"no"`.
- **`${VAR:-default}`** fallbacks on interpolated vars so a missing value fails
  loudly or defaults sanely rather than silently emptying a connection string.
- **Configurable host ports, never hardcoded.** Every published port is
  `${SOME_PORT:-<default>}` (`${API_PORT:-8080}`, `${DB_PORT:-25432}`) so a second
  stack, a host process, or a teammate's machine can override without editing the
  file. Bind local datastore ports to `127.0.0.1` so they are not exposed on the
  LAN. Conformance check `compose.ports_configurable` fails a bare `host:container`
  literal. The datastore port is the one that bites: when it is hardcoded and a
  host-run tool (a migration, an `admin create`) reads its DSN from `.env`, that
  DSN silently points at the container-internal `5432` and connects to whatever
  other project already holds host `5432`. Keep the DB host port a single
  variable, and keep `env.sample`'s host-facing `DATABASE_URL` on that same
  published `DB_PORT`, not on `5432`.
- **Prefer the host's preconfigured reverse proxy over a bundled one.** When the
  target host already runs a shared Traefik (or nginx-proxy) on an external
  `proxy` network, the prod overlay joins that network and routes via labels.
  Do **not** ship a per-app Traefik that binds 80/443: it collides with the host
  proxy and duplicates TLS. When the service is on more than one network, set
  `traefik.docker.network=<proxy-net>` or routing is non-deterministic.
- **Route the apex and www hostnames as two routers to one service**, not a
  single `Host(`a`) || Host(`www.a`)` rule: a canonical www router at
  `priority=1` plus a `-bare` apex router (see the prod block above). Both target
  the same service; splitting them keeps per-host middleware (an apex->www
  redirect, a per-host rate limit) attachable to one hostname later without
  re-splitting the rule. The apex host is a single `.env` variable, canonically
  **`APEX_DOMAIN`**, documented in `env.sample` and consumed by the `Host()`
  rules. `make up` should refuse to boot prod when it is empty or still the
  template default: see the `preflight` gate in the `10x-makefile` skill's
  `makefile-compose.md`.
- **`.env` is the single config source, auto-loaded, no `env_file:` directive.**
  Compose reads `./.env` (derived by the user from a committed `env.sample`)
  automatically for `${VAR}` interpolation. Deliver config to containers through
  an explicit `environment:` map that interpolates from it, so each container
  gets only what it reads; do not add `env_file:` (it dumps the whole file into
  the container and duplicates the mechanism). Prod keeps `.env` beside the
  compose files at mode 0600; the test overlay swaps it via `--env-file .env.test`.
  Because `docker compose` reads `.env` but `make` does not, a Makefile that
  guards on those vars (e.g. `test -n "$$APEX_DOMAIN"`) must `-include .env` and
  `export` them, or the guard sees an empty value while compose sees the real
  one. See the `10x-makefile` skill's `makefile-compose.md`.
- **Resource controls where a service can run away** (a gap most compose files
  miss). Cap file descriptors and, in prod, memory/CPU:
  ```yaml
  services:
    db:
      ulimits:
        nofile: { soft: 262144, hard: 262144 }
      deploy:
        resources:
          limits: { memory: 1g, cpus: "1.0" }
  ```
- **Omit the obsolete top-level `version:` field** (Compose v2 warns on it).
- Never set host ports or `container_name` in the base file: overlays own those.
