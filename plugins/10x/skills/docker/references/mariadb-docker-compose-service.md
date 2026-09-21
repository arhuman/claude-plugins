# MariaDB docker-compose service

Image tag verified 2026-07 (`mariadb:11` is the current LTS line; 10.4 is EOL since June 2024).

```yaml
services:
  app_db:
    image: mariadb:11
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

This block is the single authoritative MariaDB service definition (the testing Docker DB guide references it). External port `23306` avoids clashing with a locally installed MariaDB; volume and port conventions are catalogued in the docker SKILL.md.
