# Docker & Database Testing

## Docker Compose Setup

Use real DB containers with healthchecks and `depends_on: condition: service_healthy`, not merely container start. For service definitions consult Docker's [MariaDB](../../docker/references/mariadb-docker-compose-service.md) or [Oracle](../../docker/references/oracle-docker-compose-service.md) references when using those databases.

Give each database its own service/healthcheck in multi-DB projects (including MSSQL). Reference MariaDB readiness values: 5s start period, interval and timeout; 10 retries. Oracle start period: 40-60s. Nonstandard host ports avoid local collisions, e.g. `23306:3306`.

## Database Initialization Scripts

Mount `conf/docker/initdb/` at `docker-entrypoint-initdb.d/`; scripts run alphabetically on first start, schema before fixture data (`01_schema.sql`, `02_fixtures.sql`). Oracle needs a shell wrapper invoking `sqlplus` for SQL files rather than assuming native `.sql` entrypoint support.

## run_tests.sh Pattern

Start with `make up`; poll the HTTP health endpoint, not just an open port. Reference contract: `/healthcheck`, HTTP 200, 3s polling, retry limit 25. Tolerate transient curl failures during readiness. On exhaustion print error and Compose logs, stop stack, exit 1.

Once ready, run integration packages (`./internal/...` in the reference project) with Go race detection. Always stop the stack on exit, including test/startup failure; preserve test exit status. Use cleanup that survives `set -e`, rather than relying on commands after a failed test.

## Makefile Targets

When wiring targets, consult [makefile base](../../makefile/references/makefile-base.md) for up/down and [Go targets](../../makefile/references/makefile-go.md) for test/fulltest/cover/audit/ci. Test-specific wiring: `fulltest` invokes `./run_tests.sh`; `make ci` is the full pipeline.

## Test Environment Configuration

Follow [integration environment setup](integration-testing.md#environment-setup-for-tests) for env fallback and DB overrides. Resolve the actual project root in test helpers; never use production connection strings.
