# API Projects

## Directory Layout

- `cmd/api/` - Main application entry point
- `docs/` - Documentation repository
- `internal/api/` - HTTP handlers
- `internal/api/routes.go` - routes setup
- `internal/api/server.go` - server setup
- `internal/models/` - Data models and structures
- `internal/middlewares/` - JWT authentication, logging, authorization
- `internal/<domain_entity>/repository.go` - Gorm repository for <domain_entity> 
- `internal/<domain_entity>/service.go` - Service with business logic for <domain_entity>
- `internal/tools/tools.go` - Blank import of tools used in makefile to have version pinned in go.mod
- `pkg/` - Reusable/shareable modules
- `pkg/utils/` - Shared utilities (config, database, logging, auth)

## Server/Dependency Injection Pattern

In internal/api/server.go

- Use a Server struct to hold all application dependencies (repositories, services, logger, database, router, etc.)
- Initialize all dependencies in a NewServer() constructor function
- Pass dependencies as parameters to NewServer() to enable testing with mocks
- Example pattern:
```go
type Server struct {
    Repository    domain.Repository
    Service       *DomainService
    DB            *gorm.DB
    Router        *gin.Engine
    Log           *zap.Logger
    ctx           context.Context
    cancel        context.CancelFunc
    wg            sync.WaitGroup
}

func NewServer(db *gorm.DB, router *gin.Engine, log *zap.Logger) *Server {
    ctx, cancel := context.WithCancel(context.Background())
    repository := domain.NewRepository(db, log)
    service := NewService(repository, log)

    return &Server{
        Repository: repository,
        Service:    service,
        DB:         db,
        Router:     router,
        Log:        log,
        ctx:        ctx,
        cancel:     cancel,
    }
}
```

## Preferred modules

### Web Framework
- `github.com/gin-gonic/gin` - HTTP web framework
- `github.com/gin-contrib/cors` - CORS middleware
- `github.com/gin-contrib/pprof` - Profiling middleware

### Database/ORM
- `gorm.io/gorm` - ORM for database operations
- `gorm.io/driver/mysql` - MySQL driver (or other GORM drivers as needed)

### API Documentation
- `github.com/swaggo/swag` - Swagger/OpenAPI documentation generator
- `github.com/swaggo/gin-swagger` - Gin integration for Swagger
- `github.com/swaggo/files` - Static file serving for Swagger UI

### Authentication/Authorization
- `github.com/golang-jwt/jwt/v5` - JWT token handling

### Configuration
- `github.com/joho/godotenv` - Load environment variables from .env files

### Utilities
- `github.com/google/uuid` - UUID generation
- `github.com/patrickmn/go-cache` - In-memory caching

### gRPC (when needed)
- `google.golang.org/grpc` - gRPC framework
- `google.golang.org/protobuf` - Protocol Buffers support

## Configuration Pattern

See `resources/project-structure.md` for the full configuration pattern (Config struct, `os.LookupEnv`, fail-fast validation).

API-specific: load `.env` at startup before accessing any env vars:

```go
if err := godotenv.Load(".env"); err != nil {
    log.Info("no .env file, using environment variables")
}
```

## Request Body Handling

Apply `http.MaxBytesReader` before decoding, then drain and close in a deferred function. Without draining, the server cannot reuse the TCP connection.

```go
func (s *Server) createUser(w http.ResponseWriter, r *http.Request) {
    r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1 MB limit
    defer func() {
        io.Copy(io.Discard, r.Body)
        r.Body.Close()
    }()

    var req CreateUserRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        var maxErr *http.MaxBytesError
        if errors.As(err, &maxErr) {
            http.Error(w, "request too large", http.StatusRequestEntityTooLarge)
            return
        }
        http.Error(w, "invalid JSON", http.StatusBadRequest)
        return
    }
    // ...
}
```

Gin binds the body automatically but does not limit it. Apply the limit in a middleware or explicitly per handler when processing large uploads.

## Middleware Ordering

Apply middleware in this order (order matters in Gin):

1. Recovery (panic → 500)
2. CORS
3. Request ID / tracing
4. Logger
5. Rate limiter
6. Authentication (JWT)
7. Authorization
8. Business routes

## Standard JSON Error Envelope

```go
type ErrorResponse struct {
    Code    string `json:"code"`
    Message string `json:"message"`
}

// Success: { "data": ... }
// Error:   { "error": { "code": "NOT_FOUND", "message": "user not found" } }
```

## Graceful HTTP Server Shutdown

```go
srv := &http.Server{Addr: ":8080", Handler: router}
go srv.ListenAndServe()

quit := make(chan os.Signal, 1)
signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
<-quit

ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
srv.Shutdown(ctx)
```

## Zap Logger Configuration

### Production Logger Setup
- Use JSON encoding for structured logging in production
- Custom encoder configuration for standard field names:
```go
encoderCfg := zap.NewProductionEncoderConfig()
encoderCfg.TimeKey = "timegenerated"
encoderCfg.LevelKey = "log.level"
encoderCfg.EncodeTime = zapcore.RFC3339TimeEncoder
encoderCfg.EncodeLevel = zapcore.CapitalLevelEncoder
```

### Dynamic Log Level
- Use `zap.AtomicLevel` to allow runtime log level changes
- Read initial level from environment variable (e.g., `API_LOG_LEVEL`)
- Support levels: debug, info, warn, error, fatal
- Pattern:
```go
level := zap.InfoLevel
if os.Getenv("API_LOG_LEVEL") == "debug" {
    level = zap.DebugLevel
}
atomicLevel := zap.NewAtomicLevelAt(level)
config := zap.Config{
    Level: atomicLevel,
    // ... other config
}
logger := zap.Must(config.Build())
```

### Logger Configuration Fields
- Set `Development: false` for production
- Set `DisableCaller: true` to omit caller info (reduce noise)
- Set `DisableStacktrace: false` to include stack traces on errors
- Output to stderr: `OutputPaths: []string{"stderr"}`
- Error output to stderr: `ErrorOutputPaths: []string{"stderr"}`

## CORS Configuration

### Standard CORS Setup for APIs
- Use `github.com/gin-contrib/cors` middleware
- Apply CORS middleware to router before defining routes
- Pattern:
```go
config := cors.DefaultConfig()
config.AllowOrigins = []string{"*"}  // Or specific origins in production
config.AllowMethods = []string{"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"}
config.AllowHeaders = []string{"Origin", "Content-Length", "Content-Type", "Authorization"}
config.AllowCredentials = true
router.Use(cors.New(config))
```

### Production Considerations
- Replace `AllowOrigins: []string{"*"}` with specific allowed origins for production
- Set `AllowCredentials: true` when using authentication cookies or Authorization headers
