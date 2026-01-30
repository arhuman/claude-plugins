# Oracle docker-compose service

**Oracle DB Service (Architecture-Specific):**
```yaml
  # For arm64 (Apple Silicon)
  oracle_db:
    image: gvenzl/oracle-free:23.26.0
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
      start_period: 5s
    volumes:
      - ./conf/docker/initdb.oracle:/container-entrypoint-initdb.d
    networks:
      - default

  # For amd64 (x86_64)
  # oracle_db:
  #   image: oracleinanutshell/oracle-xe-11g:12.4.2
  #   container_name: oracle-db
  #   ports:
  #     - 1521:1521
  #     - 5500:5500
  #   volumes:
  #     - ./conf/docker/initdb.oracle:/docker-entrypoint-initdb.d
```

## Healthchecks

Always implement healthchecks for dependencies:

**Oracle:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe && \
    export PATH=$ORACLE_HOME/bin:$PATH && \
    /u01/app/oracle/product/11.2.0/xe/bin/lsnrctl status | grep -qi 'status.*READY' || exit 1"
  ]
  start_period: 50s
  interval: 15s
  timeout: 5s
  retries: 30
```

### Ports

**Standard Port Mappings:**
- Oracle: `1521:1521`, `5500:5500`
