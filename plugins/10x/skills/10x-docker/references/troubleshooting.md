# Docker Troubleshooting Guide

## Build Issues

| Symptom | Check |
|---------|-------|
| Slow builds | Layer caching order — dependency files must be copied before source |
| Missing files in image | `.dockerignore` may be too aggressive |
| COPY path errors | Verify paths relative to build context |
| Dependency download fails | Check network in build stage, verify base image |

## Runtime Issues

| Symptom | Check |
|---------|-------|
| Service won't start | `docker compose logs -f <service>` for error details |
| Healthcheck failing | Verify healthcheck command works inside container |
| Volume not readable | Check file ownership and permissions |
| Services can't connect | Verify service names match in `depends_on` and connection strings |
| Environment variable missing | Check `.env` file exists and variable is declared |

**Useful commands:**
```bash
docker compose logs -f service-name     # Follow logs
docker compose exec service-name sh     # Shell into container
docker compose ps                       # Check status and health
docker compose build --no-cache         # Force clean build
```

## Permission Issues

- K8S requires group 0 read access: add `chmod -R g=u /app` or equivalent
- `USER 1001` must be set; create user in Dockerfile if not present in base image
- Volume files created by container run as UID 1001 — ensure host directory is writable

## Architecture Issues

- Always specify platform or use multi-arch base images when mixing arm64/amd64
- `CGO_ENABLED=0` required for Go binaries in Alpine containers
- Strip debug symbols for smaller images: `-ldflags="-s -w"`
