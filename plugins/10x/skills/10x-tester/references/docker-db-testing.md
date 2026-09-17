# Docker & Database Testing

## Docker Compose Setup

Integration tests run against real database containers. Define services with healthchecks so dependent containers wait until the DB is actually ready.

The authoritative service definitions live in the 10x-docker skill (`references/mariadb-docker-compose-service.md` and friends); the excerpt below shows the healthcheck wiring that matters for tests.

```yaml
# docker-compose.yml
services:
  app_db:
    image: mariadb:11
    environment:
      MARIADB_ROOT_PASSWORD: rootpass
      MARIADB_DATABASE: appdb
      MARIADB_USER: appuser
      MARIADB_PASSWORD: apppass
    volumes:
      - ./conf/docker/initdb:/docker-entrypoint-initdb.d   # SQL init scripts run on first start
      - ./conf/docker/mariadb.cnf:/etc/mysql/mariadb.cnf
    ports:
      - "23306:3306"   # non-standard port avoids collision with local MySQL
    healthcheck:
      test: mysqladmin ping -h 127.0.0.1 -u root --password=rootpass
      start_period: 5s
      interval: 5s
      timeout: 5s
      retries: 10

  app_api:
    image: app-api
    build: .
    ports:
      - "8080:8080"
    volumes:
      - ./env.sample:/app/.env
    depends_on:
      app_db:
        condition: service_healthy   # wait for healthcheck, not just container start
```

For multi-database projects (MariaDB + Oracle + MSSQL), add each as a separate service with its own healthcheck. Oracle needs a longer `start_period` (40-60s) due to slow initialization.

## Database Initialization Scripts

Place SQL scripts in the volume mounted to `docker-entrypoint-initdb.d/`. They run alphabetically on first container start.

```
conf/docker/initdb/
  01_schema.sql      # DDL: CREATE TABLE ...
  02_fixtures.sql    # DML: INSERT INTO ... (test data)
```

For Oracle, use shell scripts that run `sqlplus` because Oracle's entrypoint does not natively support `.sql` files:

```bash
#!/bin/bash
# conf/docker/initdb.oracle/01_init.sh
$ORACLE_HOME/bin/sqlplus system/oracle@XE @/docker-entrypoint-initdb.d/schema.sql
```

## run_tests.sh Pattern

The standard script to start the stack, wait for the server to be ready, run tests, and clean up. Use the HTTP health endpoint check (more reliable than port polling).

```bash
#!/bin/bash
set -e

make up
echo "Waiting for server..."

MAX_RETRIES=25
CPT=0

while true; do
    sleep 3
    CPT=$((CPT + 1))

    if [ "$CPT" -ge "$MAX_RETRIES" ]; then
        echo "ERROR: server did not start after $MAX_RETRIES attempts"
        docker compose logs
        docker compose stop
        exit 1
    fi

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/healthcheck || true)

    if [ "$HTTP_CODE" -eq 200 ]; then
        echo "Server ready."
        break
    fi

    echo "  attempt $CPT: HTTP $HTTP_CODE"
done

go test -v ./internal/...
RC=$?

docker compose stop
exit $RC
```

Always stop the stack on exit, even on failure. `set -e` is fine here because the `|| true` on the `curl` call prevents false exits during the health check loop.

## Makefile Targets

Targets come from the 10x-makefile skill (single source of truth): `up`/`down` from `makefile-base.md`, `test`/`fulltest`/`cover`/`audit`/`ci` from `makefile-go.md`. The only test-specific wiring is pointing `fulltest` at the script above:

```makefile
## fulltest: start the Docker stack and run integration tests
fulltest:
	./run_tests.sh
```

## Test Environment Configuration

Tests override the DB connection to target the Docker Compose containers. Never use a production connection string in tests.

```go
// internal/api/testutil.go
func LoadTestEnv(t *testing.T) {
    t.Helper()
    root := findProjectRoot(t)

    if err := godotenv.Load(root + ".env"); err != nil {
        if err := godotenv.Load(root + "env.sample"); err != nil {
            t.Fatal("no .env or env.sample found")
        }
    }

    // Override to Docker Compose ports
    os.Setenv("DBHOST", "localhost")
    os.Setenv("DBPORT", "23306")
}

func findProjectRoot(t *testing.T) string {
    t.Helper()
    pwd, _ := os.Getwd()
    // Strip internal package path to reach project root
    return filepath.ToSlash(pwd) + "/"
}
```

## Quick Reference

| Pattern | Detail |
|---------|--------|
| DB init scripts | `conf/docker/initdb/` mounted to `docker-entrypoint-initdb.d/` |
| Non-standard port | `23306:3306` avoids collision with local MySQL |
| Health check | `depends_on: condition: service_healthy` |
| Server readiness | Poll `/healthcheck` with `curl`, not just port with `nc` |
| Test env setup | `godotenv.Load` + override DBHOST/DBPORT |
| Test target | `go test -v ./internal/...` (or the project's integration packages) |
| Full pipeline | `make ci` (see 10x-makefile `makefile-go.md`) |
