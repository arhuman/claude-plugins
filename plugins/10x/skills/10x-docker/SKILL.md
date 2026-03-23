---
name: 10x-docker
description: Docker and docker-compose best practices. Use for any Docker task: Dockerfiles (multi-stage builds, alpine, non-root), docker compose services (Go API, frontend, MariaDB, Oracle), healthchecks, volumes, networks, and K8S-compatible configurations.
---
# 10x Docker 

## Dockerfile

For Go API please follow the recommendations in ./references/go-api-dockerfile.md
For Frontend applications follow the recommendations in ./references/frontend-dockerfile.md

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

## Docker-compose.yml

- Omit version field (recommended) or use `version: '3.9'`
- Use `services:` as top-level key

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
3. **Environment:** `./env.sample:/home/dinfo/conf/.env`
4. **Logs:** `/tmp/logs:/tmp/logs`
5. **Runtime Config:** `./conf/docker/environment.json:/usr/share/nginx/html/assets/environments/environment.json`

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
- `TZ=Europe/Zurich`
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
   - `docker-compose.yml` - Main composition
   - `docker-compose.override.yml` - Local overrides
   - `docker-compose-test.yml` - Test environment
   - `docker-compose-prod.yml` - Production settings

