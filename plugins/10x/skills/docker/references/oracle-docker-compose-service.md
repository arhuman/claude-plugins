# Oracle docker-compose service

Image tag verified 2026-07. `gvenzl/oracle-free` is multi-arch (amd64 and arm64/Apple Silicon), so one service definition covers both.

```yaml
  oracle_db:
    image: gvenzl/oracle-free:23-slim
    container_name: oracle-db
    ports:
      - 1521:1521
    environment:
      ORACLE_PASSWORD: oracle
      APP_USER: TEST
      APP_USER_PASSWORD: test
    healthcheck:
      test: ["CMD", "healthcheck.sh"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
    volumes:
      - ./conf/docker/initdb.oracle:/container-entrypoint-initdb.d
    networks:
      - default
```

Notes:
- `healthcheck.sh` ships inside the gvenzl image; no custom lsnrctl probing needed.
- Use `23-full` when you need features stripped from `-slim` (Spatial, full APEX); `-slim` starts faster and is sufficient for app testing.
- Oracle startup is slow: keep `start_period` generous before declaring the container unhealthy.
