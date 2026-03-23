# Frontend Dockerfile

```dockerfile
# STAGE 1: Build
FROM node:14-alpine AS build
WORKDIR /usr/src/app
COPY conf conf
COPY e2e e2e
COPY src src
COPY angular.json package.json package-lock.json tsconfig* tslint.json ./
RUN npm install --omit=dev
RUN npm install -g @angular/cli@11.0.6
RUN ng build --prod

# STAGE 2: Run
FROM nginx:1.23.4-alpine-slim
RUN mkdir -p /usr/share/nginx/html
COPY --from=build /usr/src/app/dist/app-name /usr/share/nginx/html
COPY ./conf/docker/default.conf /etc/nginx/conf.d/default.conf
RUN chgrp -R 0 /var/cache/nginx && chmod -R g=u /var/cache/nginx
RUN touch /var/run/nginx.pid
RUN chgrp -R 0 /var/run/nginx.pid && chmod -R g=u /var/run/nginx.pid
RUN chgrp -R 0 /usr/share/nginx/html && chmod -R g=u /usr/share/nginx/html
USER 1001
```
