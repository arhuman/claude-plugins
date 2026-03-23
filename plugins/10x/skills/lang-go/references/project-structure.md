# Project Structure and Module Management

## Standard Directory Layout

```
myproject/
├── cmd/                     # Binary entry points (one dir per binary)
│   ├── server/
│   │   └── main.go
│   └── worker/
│       └── main.go
├── internal/                # Private code — cannot be imported outside this module
│   ├── api/                 # HTTP handlers and routing
│   ├── service/             # Business logic
│   └── repository/          # Data access layer
├── pkg/                     # Public library code (importable by other modules)
│   └── models/
├── api/                     # API contracts (OpenAPI specs, protobuf definitions)
│   ├── openapi.yaml
│   └── proto/
├── configs/                 # Configuration files and templates
├── deployments/             # Docker, Kubernetes, Terraform
├── scripts/                 # Build, migration, and maintenance scripts
├── test/                    # Integration test data and helpers
├── docs/                    # Architecture docs, ADRs
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

## internal/ — Enforced Visibility Boundary

`internal/` is the most important layout concept in Go. The compiler prevents any package outside the module from importing `internal/` packages.

```
myproject/
└── internal/
    ├── auth/           # importable by myproject only
    └── database/       # importable by myproject only

// From another module — this FAILS at compile time:
import "github.com/user/myproject/internal/auth"
```

Put everything that is not intentionally a public API inside `internal/`. Use `pkg/` sparingly — only for code you explicitly want other modules to import.

## go.mod Basics

```
module github.com/user/myproject

go 1.22

require (
    github.com/gin-gonic/gin v1.9.1
    go.uber.org/zap v1.27.0
)

// Local development: point to a local copy
replace github.com/user/mylib => ../mylib

// Retract a bad release
retract v1.0.1 // Contains critical bug
```

## Module Commands

```bash
go mod init github.com/user/project  # Initialize new module
go mod tidy                          # Add missing, remove unused dependencies
go mod download                      # Download all dependencies to cache
go mod verify                        # Verify dependencies haven't been tampered
go mod vendor                        # Copy deps to vendor/ for offline builds

go get github.com/user/pkg@v1.2.3    # Add or update to specific version
go get -u ./...                      # Update all dependencies to latest minor/patch
go mod why github.com/user/pkg       # Explain why a package is in the module graph
```

## Monorepo with go.work

Use Go workspaces when multiple modules in the same repo need to reference each other.

```
monorepo/
├── go.work
├── services/
│   ├── api/
│   │   ├── go.mod
│   │   └── main.go
│   └── worker/
│       ├── go.mod
│       └── main.go
└── shared/
    └── models/
        ├── go.mod
        └── user.go
```

```
// go.work
go 1.22

use (
    ./services/api
    ./services/worker
    ./shared/models
)
```

```bash
go work init ./services/api ./services/worker
go work use ./shared/models
go work sync
```

## Build Tags

```go
//go:build linux && amd64

package myapp

// Multiple constraints
//go:build linux || darwin

// Negate
//go:build !windows

// Integration test separation
//go:build integration

package myapp_test
```

Run with tag: `go test -tags=integration ./...`

## Makefile

```makefile
.PHONY: build test lint fmt clean run

BINARY  := bin/server
GOFLAGS := -v

build:
	go build $(GOFLAGS) -o $(BINARY) ./cmd/server

test:
	go test -race -coverprofile=coverage.out ./...

test-cover: test
	go tool cover -html=coverage.out

lint:
	golangci-lint run ./...

fmt:
	gofmt -w .
	goimports -w .

run:
	go run ./cmd/server

clean:
	rm -rf bin/ coverage.out

# Cross-compile
build-all:
	GOOS=linux  GOARCH=amd64 go build -o bin/server-linux-amd64    ./cmd/server
	GOOS=darwin GOARCH=amd64 go build -o bin/server-darwin-amd64   ./cmd/server
	GOOS=linux  GOARCH=arm64 go build -o bin/server-linux-arm64    ./cmd/server

generate:
	go generate ./...

docker-build:
	docker build -t myapp:latest .

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'
```

## Dockerfile Multi-Stage Build

```dockerfile
# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -o server ./cmd/server

# Final stage — minimal image
FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app
COPY --from=builder /app/server .

EXPOSE 8080
ENTRYPOINT ["./server"]
```

## Version Injection via ldflags

```go
// version/version.go
package version

import "runtime"

var (
    Version   = "dev"      // set via ldflags
    GitCommit = "none"
    BuildTime = "unknown"
)

func Info() map[string]string {
    return map[string]string{
        "version":    Version,
        "git_commit": GitCommit,
        "build_time": BuildTime,
        "go_version": runtime.Version(),
    }
}
```

```bash
go build -ldflags "-X github.com/user/project/version.Version=1.2.0 \
  -X github.com/user/project/version.GitCommit=$(git rev-parse --short HEAD) \
  -X github.com/user/project/version.BuildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  ./cmd/server
```

## go generate and Tool Dependencies

```go
// Track tool dependencies in tools.go (excluded from production build)
//go:build tools

package tools

import (
    _ "github.com/vektra/mockery/v2"
    _ "golang.org/x/tools/cmd/stringer"
    _ "github.com/swaggo/swag/cmd/swag"
)
```

```go
// In the file that needs generation:
//go:generate mockery --name=UserRepository --output=./mocks

// Run:
// go generate ./...
```

## Configuration Management

Prefer environment variables + typed config structs. Fail fast on missing required config.

```go
// config/config.go
package config

import (
    "fmt"
    "os"
    "strconv"
    "time"
)

type Config struct {
    Server   ServerConfig
    Database DatabaseConfig
}

type ServerConfig struct {
    Host         string
    Port         int
    ReadTimeout  time.Duration
    WriteTimeout time.Duration
}

type DatabaseConfig struct {
    URL          string
    MaxOpenConns int
    MaxIdleConns int
}

func Load() (*Config, error) {
    dbURL, ok := os.LookupEnv("DATABASE_URL")
    if !ok {
        return nil, fmt.Errorf("config: DATABASE_URL is required")
    }
    port, _ := strconv.Atoi(getEnvOrDefault("SERVER_PORT", "8080"))
    return &Config{
        Server:   ServerConfig{Host: getEnvOrDefault("SERVER_HOST", "0.0.0.0"), Port: port},
        Database: DatabaseConfig{URL: dbURL, MaxOpenConns: 25, MaxIdleConns: 5},
    }, nil
}

func getEnvOrDefault(key, def string) string {
    if v, ok := os.LookupEnv(key); ok {
        return v
    }
    return def
}
```

## Quick Reference

| Command | Description |
|---------|-------------|
| `go mod init` | Initialize module |
| `go mod tidy` | Sync dependencies |
| `go get pkg@version` | Add/update dependency |
| `go work init` | Initialize workspace (monorepo) |
| `go generate ./...` | Run code generation |
| `GOOS=linux go build` | Cross-compile |
| `go build -ldflags "-X ..."` | Inject version info |
| `go test -tags=integration` | Run integration tests |
