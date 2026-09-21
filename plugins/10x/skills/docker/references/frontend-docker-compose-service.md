# Frontend application docker-compose

**Simple Frontend Service:**
```yaml
  web:
    build: .
    hostname: web
    ports:
      - "8080:8080"
    volumes:
      - ./conf/docker/environment.json:/usr/share/nginx/html/assets/environments/environment.json
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:8080/ >/dev/null || exit 1"]
      start_period: 5s
      interval: 10s
      timeout: 5s
      retries: 5
```

Note: `nginx:alpine` images include BusyBox `wget`, so the healthcheck needs no extra packages. The port matches the non-root nginx config from `frontend-dockerfile.md`.
