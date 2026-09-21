# Go API docker-compose

**Go API Service:**
```yaml
  app_api:
    image: app-api
    container_name: app-api
    build:
      context: .
      dockerfile: ${DOCKERFILE:-Dockerfile}
    restart: always
    # Host port configurable with a default; container port fixed at 8080.
    ports:
      - "${API_PORT:-8080}:8080"
    # Config from the auto-loaded ./.env (derived from env.sample) via an
    # explicit environment: map. No env_file: directive, no bind-mounting the
    # sample into the container.
    environment:
      APP_DB_DSN: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@app_db:5432/${POSTGRES_DB}?sslmode=disable
      APP_JWT_SECRET: ${JWT_SECRET}
    networks:
      - default
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:8080/health >/dev/null || exit 1"]
      start_period: 5s
      interval: 10s
      timeout: 5s
      retries: 5
    depends_on:
      app_db:
        condition: service_healthy
```

Notes:
- The healthcheck assumes a `/health` endpoint and `wget` in the runtime image (installed by `go-api-dockerfile.md`); adjust the path to the API's actual liveness route.
- The container port is fixed at 8080; only the host side is configurable (`${API_PORT:-8080}`). Do not make the container port a variable.
- Config reaches the container through the `environment:` map, interpolated from the auto-loaded `.env`. `container_name`, `ports`, and `restart` shown here belong in an overlay, not the neutral base (see `docker-compose-environments.md`).
- Downstream services can then use `depends_on: app_api: condition: service_healthy` instead of sleep loops.
