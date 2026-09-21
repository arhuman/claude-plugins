# API Projects

## Directory Layout

Apply the [layout ceiling and ownership rules](project-structure.md): `cmd/api/` entry, `docs/` documentation, `internal/api/{routes,server}.go` transport setup, `internal/middlewares/` auth/logging, `internal/<domain_entity>/{repository,service}.go` GORM/business logic, `internal/tools/tools.go` pinned tool imports. `internal/models/` only for genuine shared vocabulary; `pkg/` (including utilities) only for intentionally public capabilities.

## Server/Dependency Injection Pattern

Use `Server` in `internal/api/server.go` to hold the router, services/repositories, DB, logger and any server context/cancel/WaitGroup. `NewServer` receives dependencies for isolated tests and initializes server-specific state. Process dependency construction belongs to [internal/app](project-structure.md#composition-root-internalapp), not duplicate DB/logger/service wiring in adapters. Apply [constructor defaults](interfaces.md#constructors-normalize-nil-dependencies).

## Preferred modules

Choose modules only for needed capabilities; the entry skill's minimal-dependency policy applies.

### Web Framework

`github.com/gin-gonic/gin`; `github.com/gin-contrib/cors`; `github.com/gin-contrib/pprof`.

### Database/ORM

`gorm.io/gorm`; `gorm.io/driver/mysql` or the required GORM dialect driver. [errors](errors.md#repository-context-pattern-gorm) owns context binding.

### API Documentation

Use the modules and generation contract in [OpenAPI](openapi.md).

### Authentication/Authorization

`github.com/golang-jwt/jwt/v5`.

### Configuration

`github.com/joho/godotenv`.

### Utilities

`github.com/google/uuid`; `github.com/patrickmn/go-cache`.

### gRPC (when needed)

`google.golang.org/grpc`; `google.golang.org/protobuf`.

## Configuration Pattern

Use [typed config and fail-fast validation](project-structure.md#configuration-management). Before accessing environment variables at API startup, call `godotenv.Load(".env")`; if absent, log that environment variables are being used.

## Request Body Handling

Apply [memory's handler body lifecycle](memory.md#request-body-handlers); this is also required with Gin binding.

## Middleware Ordering

Register in order: Recovery (panic to 500), CORS, request ID/tracing, logger, rate limiter, JWT authentication, authorization, business routes.

## Standard JSON Error Envelope

Success uses `{ "data": ... }`; errors use `{ "error": { "code": "NOT_FOUND", "message": "user not found" } }`. Define the response wrappers once and reference those concrete types in OpenAPI.

## Graceful HTTP Server Shutdown

Serve with `http.Server`; on SIGINT/SIGTERM call `Shutdown` using a fresh bounded context (e.g. five seconds), defer its cancel and handle server/shutdown errors. Do not abandon inflight requests on signal receipt.

## Zap Logger Configuration

For existing Zap projects (new logger selection is in [slog](slog.md)):

### Production Logger Setup

Use JSON and this encoder configuration:

```go
encoderCfg := zap.NewProductionEncoderConfig()
encoderCfg.TimeKey = "timegenerated"
encoderCfg.LevelKey = "log.level"
encoderCfg.EncodeTime = zapcore.RFC3339TimeEncoder
encoderCfg.EncodeLevel = zapcore.CapitalLevelEncoder
```

### Dynamic Log Level

Use `zap.AtomicLevel`; initialize from environment (e.g. `API_LOG_LEVEL`), supporting debug/info/warn/error/fatal and runtime changes. Logging level/event rules are owned by [slog](slog.md#slog-the-default-logger).

### Logger Configuration Fields

Production: `Development: false`, `DisableCaller: true`, `DisableStacktrace: false`, `OutputPaths: []string{"stderr"}`, `ErrorOutputPaths: []string{"stderr"}`.

## CORS Configuration

### Standard CORS Setup for APIs

Use gin-contrib/cors before routes. Methods: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS. Headers: Origin, Content-Length, Content-Type, Authorization.

### Production Considerations

Use explicit production origins rather than `*`; enable `AllowCredentials` when using authentication cookies or Authorization headers. Gate: middleware order, origins/credentials, body handling, one response contract and bounded shutdown match the actual server.
