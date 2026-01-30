# Dockerfile for Go API

#### Multi-Stage Go Dockerfile

**Production Dockerfile:**
```dockerfile
# STEP 1: build
FROM golang:1.25 AS builder
WORKDIR /api
COPY go.* /api/
RUN go mod download
COPY cmd cmd/
COPY internal internal/
COPY docs docs/
RUN CGO_ENABLED=0 GOOS=linux GOFLAGS="-ldflags=-s -ldflags=-w" go build -o server ./cmd/api/

# STEP 2: app
FROM golang:1.25-trixie
ENV TZ=Europe/Zurich
RUN apt-get update && apt-get install ca-certificates -y && rm -rf /var/cache/apk/*
RUN groupadd dinfo && useradd -r --uid 1001 -g dinfo dinfo
RUN mkdir -p /home/dinfo/data
WORKDIR /home/dinfo
COPY --from=builder /api/server /home/dinfo/server
COPY docs docs/
RUN chgrp -R 0 /home/dinfo && chmod -R g=u /home/dinfo
USER 1001
CMD ["/home/dinfo/server"]
```
