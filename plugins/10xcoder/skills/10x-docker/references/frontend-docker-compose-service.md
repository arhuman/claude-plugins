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
```
