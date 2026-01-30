# MariaDB docker-compose service

**MariaDB Service:**

```yaml
services:
  app_db:
    image: mariadb:10.4
    container_name: app-db
    environment:
      - MARIADB_ROOT_PASSWORD=password
      - MARIADB_DATABASE=dbname
      - MARIADB_USER=user
      - MARIADB_PASSWORD=password
    volumes:
      - ./conf/docker/initdb:/docker-entrypoint-initdb.d
      - ./conf/docker/mariadb.cnf:/etc/mysql/mariadb.cnf
    ports:
      - "23306:3306"
    networks:
      - default
    healthcheck:
      test: mysqladmin ping -h 127.0.0.1 -u root --password=password
      start_period: 5s
      interval: 5s
      timeout: 5s
      retries: 10
```

## Healthchecks

Always implement healthchecks for dependencies:

```yaml
healthcheck:
  test: mysqladmin ping -h 127.0.0.1 -u root --password=1234
  start_period: 5s
  interval: 5s
  timeout: 5s
  retries: 10
```

### Volumes

**Common Volume Patterns:** `./conf/docker/mariadb.cnf:/etc/mysql/mariadb.cnf`

### Ports

**Standard Port Mappings:**
- MariaDB: `23306:3306` (non-conflicting external port)

