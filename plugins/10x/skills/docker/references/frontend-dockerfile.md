# Frontend Dockerfile

Image tags verified 2026-07.

```dockerfile
# STAGE 1: Build
FROM node:22-alpine AS build
WORKDIR /usr/src/app
COPY package.json package-lock.json ./
RUN npm ci
COPY angular.json tsconfig*.json ./
COPY src src
RUN npx ng build --configuration production

# STAGE 2: Run
FROM nginx:1.27-alpine
RUN mkdir -p /usr/share/nginx/html
# Angular application builder (v17+) outputs to dist/<app-name>/browser
COPY --from=build /usr/src/app/dist/app-name/browser /usr/share/nginx/html
COPY ./conf/docker/default.conf /etc/nginx/conf.d/default.conf
RUN chgrp -R 0 /var/cache/nginx && chmod -R g=u /var/cache/nginx
RUN touch /var/run/nginx.pid
RUN chgrp -R 0 /var/run/nginx.pid && chmod -R g=u /var/run/nginx.pid
RUN chgrp -R 0 /usr/share/nginx/html && chmod -R g=u /usr/share/nginx/html
USER 1001
```

Notes:
- `npm ci` (not `npm install --omit=dev`): the build stage needs devDependencies to compile; the runtime stage copies only the built artifacts, so pruning buys nothing.
- Use the project's local Angular CLI via `npx ng`; do not install a pinned global CLI.
