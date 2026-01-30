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
    ports:
      - "8080:${API_PORT}"
    volumes:
      - ./env.sample:/home/dinfo/conf/.env
    networks:
      - default
    depends_on:
      app_db:
        condition: service_healthy
```
