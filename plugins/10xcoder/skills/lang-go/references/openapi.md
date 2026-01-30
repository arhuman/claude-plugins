# OpenAPI with swaggo (Go)

Go projects use [swaggo/swag](https://github.com/swaggo/swag) to generate OpenAPI 2.0 (Swagger) specs from
docstring annotations. The spec is served live via `gin-swagger`.

## Setup

```bash
# Install swag CLI
go install github.com/swaggo/swag/cmd/swag@v1.16.4

# Add dependencies
go get github.com/swaggo/swag
go get github.com/swaggo/gin-swagger
go get github.com/swaggo/files
```

## Generate the Spec

```bash
# Parse from main.go entry point; follow imported packages
swag init -g cmd/api/main.go --parseDependency --parseInternal
```

This writes `docs/docs.go`, `docs/swagger.json`, and `docs/swagger.yaml`. Commit these files or
regenerate in CI. Add a Makefile target:

```makefile
.PHONY: swagger
swagger: tools
	swag init -g cmd/api/main.go --parseDependency --parseInternal
```

## main.go — Global Annotations

Place global annotations in the `main` function comment block and import the generated `docs` package
so `swag` finds it:

```go
// Package main is the entry point for the API server.
package main

import (
    docs "github.com/yourorg/yourapp/docs" // required — triggers docs registration
    _ "github.com/swaggo/swag"
)

// @title        My API
// @version      1.0
// @description  Short description of the API.
// @contact.name API Support
// @contact.email support@example.com
// @host         api.example.com
// @BasePath     /v1
//
// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
// @description Type "Bearer" followed by a space and JWT token.
func main() {
    docs.SwaggerInfo.Title = "My API" // can also override at runtime
    // ...
}
```

## routes.go — Register the UI Endpoint

```go
import (
    swaggerFiles "github.com/swaggo/files"
    ginSwagger    "github.com/swaggo/gin-swagger"
)

// Serve Swagger UI at /v1/docs/
router.GET("/v1/docs/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
```

## Handler Annotations

Every exported handler that should appear in the spec needs a `godoc` comment block immediately above
the function signature. All annotation lines start with `//` and use `@` tags.

### Complete Example

```go
// CreateUser godoc
// @Summary     Create a new user
// @Description Registers a new user account and returns the created resource.
// @Tags        Users
// @Accept      json
// @Produce     json
// @Param       body body CreateUserRequest true "User payload"
// @Success     201 {object} User
// @Failure     400 {object} ErrorResponse "Invalid request body"
// @Failure     409 {object} ErrorResponse "User already exists"
// @Failure     500 {object} ErrorResponse "Internal server error"
// @Security    BearerAuth
// @Router      /users [post]
func (s *Server) CreateUser(c *gin.Context) { /* ... */ }
```

### Annotation Reference

| Annotation | Format | Example |
|---|---|---|
| `@Summary` | Short title (< 120 chars) | `@Summary List users` |
| `@Description` | Longer explanation (markdown OK) | `@Description Returns paginated list.` |
| `@Tags` | Comma-free group name (one per line) | `@Tags Users` |
| `@Accept` | MIME type | `@Accept json` |
| `@Produce` | MIME type | `@Produce json` |
| `@Param` | `name location type required "desc"` | see below |
| `@Success` | `code {kind} Type "desc"` | `@Success 200 {object} User` |
| `@Failure` | `code {kind} Type "desc"` | `@Failure 404 {object} ErrorResponse "not found"` |
| `@Security` | scheme name defined globally | `@Security BearerAuth` |
| `@Router` | `path [method]` | `@Router /users/{id} [get]` |
| `@Deprecated` | (no value) | `@Deprecated` |

### @Param Locations

| Location | Keyword | Example |
|---|---|---|
| JSON body | `body` | `@Param body body CreateUserRequest true "payload"` |
| Path segment | `path` | `@Param id path string true "User ID"` |
| Query string | `query` | `@Param limit query int false "Page size"` |
| Header | `header` | `@Param X-Request-ID header string false "Trace ID"` |
| Form field | `formData` | `@Param file formData file true "Upload"` |

### Response Kinds

| Kind | Use for |
|---|---|
| `{object}` | Single struct |
| `{array}` | Slice of structs |
| `{string}` | Plain string |
| `{integer}` | Integer |

Use a package-qualified type when the struct lives in another package: `{object} models.User`.

## Reusable Response Structs

Define shared response wrappers once and reference them across handlers:

```go
// Response is the standard envelope for API responses.
type Response struct {
    Message string        `json:"message"`
    Values  []interface{} `json:"values,omitempty"`
}

// ErrorResponse is the standard error envelope.
type ErrorResponse struct {
    Error struct {
        Code    string `json:"code" example:"RESOURCE_NOT_FOUND"`
        Message string `json:"message" example:"User 123 not found"`
    } `json:"error"`
}
```

Use `example` struct tags to populate sample values in the generated spec.

## Struct Tags for Schema Generation

swag reads Go struct fields to build schema definitions. Useful tags:

```go
type CreateUserRequest struct {
    Email    string `json:"email"    binding:"required" example:"user@example.com"`
    Name     string `json:"name"     binding:"required" minLength:"1" maxLength:"100" example:"Jane Doe"`
    Role     string `json:"role"     enums:"admin,editor,viewer" default:"viewer"`
    Age      int    `json:"age,omitempty" minimum:"0" maximum:"120"`
    Tags     []string `json:"tags"   uniqueItems:"true"`
}
```

Supported extra tags: `example`, `enums`, `default`, `minimum`, `maximum`, `minLength`,
`maxLength`, `format`, `readOnly`.

## Security Schemes

### Bearer JWT (most common)

```go
// In main.go comment:
// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization

// Per-handler:
// @Security BearerAuth
```

### Basic Auth

```go
// In main.go:
// @Security                  BasicAuth
// @securityDefinitions.basic BasicAuth
```

### OAuth2

```go
// In main.go:
// @securityDefinitions.oauth2.accessCode OAuth2
// @tokenUrl https://auth.example.com/oauth/token
// @authorizationUrl https://auth.example.com/oauth/authorize
// @scope.read:users Read user data
// @scope.write:users Write user data
```

## Multiple Tags per Handler

Use one `@Tags` line per tag (do not comma-separate):

```go
// @Tags entra
// @Tags config
```

## Path Parameters with Gin

Use `:param` in the Gin route but `{param}` in `@Router`:

```go
// @Router /users/{id} [get]
func (s *Server) GetUser(c *gin.Context) {
    id := c.Param("id")
}
```

## Healthcheck (No Spec Entry Needed)

Unauthenticated utility routes (healthcheck, metrics, pprof) typically should NOT be annotated —
they clutter the spec. Register them outside the versioned group and omit annotations.

## Best Practices

1. **godoc first** — the comment above the handler must start with `FuncName godoc` or swag may skip it.
2. **Always add `@Failure`** — document 400, 401, 403, 404, 500 for every protected endpoint.
3. **Always add `@Security`** — any route behind JWT middleware must declare its scheme.
4. **Use concrete types, not `interface{}`** — `{object} MyResponse` gives a useful schema; `{object} interface{}` does not.
5. **Re-generate after every handler change** — treat `docs/` as generated output; add `make swagger` to CI.
6. **Validate** — run `swagger-cli validate docs/swagger.json` or `spectral lint docs/swagger.yaml` in CI.
7. **Group logically** — consistent `@Tags` values produce a clean, navigable Swagger UI.
