# Docker Compose Makefile Targets (multi-environment)

Use these when the project ships a neutral base `docker-compose.yml` plus
per-environment overlays (`docker-compose.local.yml`, `.prod.yml`, `.test.yml`)
: the layout the `docker` skill prescribes. They replace the base skeleton's
single-file `up`/`down` with a composed-command pattern so every target invokes
the same `docker compose -f base -f overlay` combination and the files never
drift from the Makefile.

If the project has only one compose file, keep the base skeleton's simple
`up`/`down` instead; do not add this complexity unprompted.

## Variables

Build the compose command once as a variable, then layer overlays on top. This
is the single source of truth for which files each environment merges.

```makefile
ENV_FILE ?= .env

# `docker compose` reads .env on its own, but `make` does not: -include it and
# export so recipe shells (e.g. the preflight domain guard) see the real values.
# The leading `-` keeps a missing .env from erroring; `preflight` catches that.
-include $(ENV_FILE)
export

# Host port the local stack publishes. Exported so `docker compose` interpolation
# (${API_PORT:-8080} in docker-compose.local.yml) resolves to the same value the
# `local` target prints. Override per run: `make local API_PORT=9090`.
API_PORT ?= 8080
export API_PORT

BASE_COMPOSE  := docker compose --env-file $(ENV_FILE) -f docker-compose.yml
LOCAL_COMPOSE := $(BASE_COMPOSE) -f docker-compose.local.yml
PROD_COMPOSE  := $(BASE_COMPOSE) -f docker-compose.prod.yml
# Test stack runs under its own project name so its network/volumes are
# namespaced and can run alongside the local stack.
TEST_COMPOSE  := docker compose -p $(PROJECT)-test --env-file .env.test \
	-f docker-compose.yml -f docker-compose.test.yml

# service= and svc= let callers target one service: `make logs service=api`
service ?=
```

Add to `.PHONY`:

```makefile
.PHONY: local up preflight down restart rebuild clean logs shell db-shell test-up test-down
```

## Targets

```makefile
## local: start the local dev stack (published ports, dev env)
local: $(ENV_FILE)
	$(LOCAL_COMPOSE) up -d --build
	@echo "local stack up: http://localhost:$(API_PORT)"

## up: start the production stack in detached mode (gated by preflight)
up: preflight
	$(PROD_COMPOSE) up -d --build
	@echo "prod stack up: routed via Traefik on www.$${APEX_DOMAIN}"

## preflight: fail unless .env holds production-ready values (gates `make up`)
# Deliberately NOT a $(ENV_FILE) prerequisite: prod must never boot on template
# defaults, so a missing .env is a hard failure, not an auto-created placeholder
# (that is what `make local` is for). `make` does not read `.env`, so the guards
# below rely on the top-level `-include $(ENV_FILE)` + `export` (see Variables).
preflight:
	@test -f $(ENV_FILE) || { echo "$(ENV_FILE) missing: cp env.sample $(ENV_FILE) and fill it before prod" >&2; exit 1; }
	@bad=""; \
	[ "$$ADMIN_PASSWORD" != change-me ] || bad="$$bad\n  ADMIN_PASSWORD is still the env.sample default"; \
	[ -n "$$SIGNING_SECRET" ]           || bad="$$bad\n  SIGNING_SECRET is empty (sessions reset on every restart)"; \
	[ -n "$$APEX_DOMAIN" ]              || bad="$$bad\n  APEX_DOMAIN is empty (Traefik Host() rules need it)"; \
	[ "$$APEX_DOMAIN" != example.com ]  || bad="$$bad\n  APEX_DOMAIN is still the env.sample default"; \
	if [ -n "$$bad" ]; then printf "preflight failed:$$bad\n" >&2; exit 1; fi; \
	echo "preflight OK: $(ENV_FILE) looks production-ready"

## down: stop and remove the local stack
down:
	$(LOCAL_COMPOSE) down

## restart: restart one service (usage: make restart service=api)
restart:
	$(LOCAL_COMPOSE) restart $(service)

## rebuild: rebuild images from scratch, no cache
rebuild:
	$(LOCAL_COMPOSE) build --no-cache

## clean: stop the stack and remove images, named volumes, and orphans
clean: confirm
	$(LOCAL_COMPOSE) down --rmi all --volumes --remove-orphans

## logs: tail logs (usage: make logs service=api)
logs:
	$(LOCAL_COMPOSE) logs -f $(service)

## shell: open a shell in a running service (usage: make shell service=api)
shell:
	$(LOCAL_COMPOSE) exec $(service) sh

## db-shell: open a psql shell in the database service
db-shell:
	$(LOCAL_COMPOSE) exec db psql -U $${POSTGRES_USER} -d $${POSTGRES_DB}

## test-up: start the isolated test stack and wait for health
test-up:
	$(TEST_COMPOSE) up -d --build
	@echo "waiting for services to become healthy..."
	@until $(TEST_COMPOSE) exec -T db pg_isready -U $${POSTGRES_USER} >/dev/null 2>&1; do sleep 1; done

## test-down: tear down the isolated test stack and its volumes
test-down:
	$(TEST_COMPOSE) down --volumes --remove-orphans
```

## Env bootstrap

Make `.env` a file target so any compose command that needs it creates it from
the committed sample on first run, instead of failing:

```makefile
## $(ENV_FILE): create the env file from the sample if missing
$(ENV_FILE):
	cp env.sample $(ENV_FILE)
```

Targets that read `$(ENV_FILE)` (like `local`/`up`) declare it as a prerequisite
so the sample is copied automatically. `env.sample` is committed; `.env` is not.

## Rules

- Always `docker compose` (v2), never `docker-compose` (v1).
- Never publish ports or set `container_name` in the base file: overlays add
  those. See the `docker` skill for the compose-file layout these targets
  drive.
- Gate destructive targets (`clean`) on the base skeleton's `confirm` target.
- Point the app at other services by compose service name, not host ports.
- The published host port is an overridable `?=` variable (`API_PORT ?= 8080`,
  `export`ed so compose interpolation resolves it), never hardcoded in the recipe,
  and `make local` prints the URL it serves on. Enforced by the `makefile.local_run`
  and `makefile.local_port` checks in `standard.yml`.
- **`make up` is gated by `preflight`, never by `$(ENV_FILE)`.** `local` may
  bootstrap a template `.env`; prod must not. `preflight` hard-fails on a missing
  `.env` or a secret/domain still at its `env.sample` default, so production
  cannot boot on placeholder values. Guard the unsafe-by-default secrets (admin
  password, JWT/signing secret, DB password) and, for a domain-routed stack, the
  reverse-proxy domain (`APEX_DOMAIN`, driving the Traefik `Host()` rules). The
  `makefile.prod_preflight` check in `standard.yml` requires the gate whenever the
  prod overlay is a real deployment: it routes a domain OR publishes a host port
  while injecting secret env vars (a service fronted by the host's own proxy).
  A stack fronted by the host reverse proxy (no Traefik labels) guards its secrets
  here and lets the proxy own the domain, so an `APEX_DOMAIN` guard is optional there.
