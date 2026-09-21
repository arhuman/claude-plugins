# REST Design Patterns

## Resource-Oriented Architecture

### Resource Identification

URIs identify resources, not actions: collection `/users`, individual `/users/{id}`, child `/users/{id}/orders`. Express actions through HTTP methods, never `/getUser`, `/createUser` or `?action=delete`.

### Resource Naming Conventions

Use plural lowercase hyphenated collection names; maximum 2-3 nesting levels. Filter through query parameters.

## HTTP Method Semantics

### Safe and Idempotent Methods

| Method | Safe | Idempotent | Purpose |
|--------|------|------------|---------|
| GET | Yes | Yes | Retrieve |
| POST | No | No by default | Create/non-idempotent operation |
| PUT | No | Yes | Full replacement |
| PATCH | No | Not guaranteed | Partial update |
| DELETE | No | Yes | Remove |
| HEAD | Yes | Yes | Metadata |
| OPTIONS | Yes | Yes | Allowed methods |

### Method Usage

Apply the method/status contracts below; JSON requests/responses declare their media types. Creation returns the created resource with Location; DELETE 204 has no body.

## HTTP Status Codes

### Success Codes (2xx)

200: successful GET/PUT/PATCH; 201: created POST with Location; 202: accepted async processing; 204: successful no-content operation.

### Redirection (3xx)

301: permanent move; 302: temporary redirect; 304: valid cached representation.

### Client Errors (4xx)

400: invalid syntax/validation; 401: missing/failed authentication; 403: authenticated but unauthorized; 404: absent resource; 405: unsupported method; 409: state conflict/duplicate; 422: syntactically valid but semantically invalid; 429: rate limit.

### Server Errors (5xx)

500: unexpected failure; 502: invalid upstream response; 503: temporary unavailability; 504: upstream timeout.

## HATEOAS (Hypermedia)

### Hypermedia-Driven APIs

Include related resources and available actions as links: `_links.self`, child collection links, update/delete links with `href` and `method`.

### HAL (Hypertext Application Language)

When using HAL, use `_links` for navigation and `_embedded` for included related resources, each with its own self link.

## Content Negotiation

### Accept Headers

Honor supported Accept types such as `application/json`, `application/xml`, `application/hal+json`.

### Response Content-Type

Set the actual response media type: e.g. `application/json; charset=utf-8`, `application/problem+json`, or `application/hal+json`.

## Idempotency

### Idempotent Operations

Repeated identical PUTs preserve the same final state. DELETE may return 204 then 404 while remaining idempotent. When POST needs idempotency (e.g. payments), accept `Idempotency-Key`, persist its response and replay that response for duplicates.

## Cache Control

### Cache Headers

Choose explicit policy: `public, max-age=3600`, `private, no-cache`, or `no-store` as appropriate. Supply `ETag`/`Last-Modified` validators when supporting conditional requests.

### Conditional Requests

Matching `If-None-Match` on GET returns 304; stale `If-Match` on PUT returns 412 Precondition Failed.

## URI Patterns

### Consistent URI Structure

Use `/{version}/{resource}[/{id}[/{sub-resource}[/{sub-id}]]]`; plan versioning from the start.

### Query Parameters

Support filters (`status`, `role`, `price_min`, `price_max`), sorting (`sort=created_at`, `sort=-created_at`, `sort=name,created_at`), field selection (`fields=id,name`, `exclude=...`) and search (`q` or `search`). Return pagination/filter/sort metadata. Choose snake_case or camelCase field naming consistently.

## Best Practices

Gate: verify resource/method/status consistency, filtering, navigation, versioning, HTTPS, authentication and rate limits. Document API examples/error codes through [OpenAPI](openapi.md).
