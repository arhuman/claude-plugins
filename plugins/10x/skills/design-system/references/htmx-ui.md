# HTMX UI Architecture

For attribute mechanics load `../../lang-html/references/htmx.md`.

## The fragment is the unit

1. One self-sufficient fragment per route (`/htmx/*`, `/modal/*`, `/form/submit/*`). One handler selects layout/fragment from `HX-Request` via shared `serveHTMX`.
2. Mandatory Domain -> ViewModel -> template; templates only loop/branch, never receive domain objects. Views in `internal/api/views/`.
3. Handler -> service -> repository. Services import neither `net/http` nor `html/template`; guard with `go list` test.
4. Auth-level route groups in one `routes.go`.
5. Explicit business actions, not raw status PATCH. Every transition appends to `activities`/`event_logs` for timelines/KPIs; snapshot human labels before deletion.
6. Paginate or cap every list server-side (e.g. 500 rows) with a truncation flag.

## HX-Trigger event contract (mandatory)

Every mutation emits entity+verb `HX-Trigger` (`taskUpdated`); names belong in one Go constants file, never inline literals. Every entity list subscribes to all its events:

```html
hx-trigger="load once, taskUpdated from:body, taskCompleted from:body, taskDeleted from:body"
```

Ship listeners in scaffolds. Adding an event requires constant, emitter, every affected `<event> from:body` listener and coupling test. CI fails events without subscribers.

## Ten gotchas (each one is a past incident)

1. Swaps: `200` + empty body + `HX-Trigger`, never `204` (skips swap).
2. `HX-Location` discards body; close modal explicitly on trigger side.
3. `json-enc` sends numeric selects as strings; DTOs use `*string` + `strconv`, not `*int`.
4. Keep field names consistent (`project_ids` vs `project_id`); shared one-value-to-slice normalization.
5. Downloads: `<a href="..." download>`, not `hx-get`; zero results still return a valid empty document, not a toast.
6. Relative/empty `hx-get` can swap a full page recursively; guard loading skeleton with `{{ if .HTMXPath }}`.
7. Reinitialize widgets on `htmx:afterSwap`, not only `DOMContentLoaded`.
8. Auth pages: `Cache-Control: no-store` to prevent cached full-page swaps.
9. Action buttons within `<summary>` call both `stopPropagation()` and `preventDefault()`.
10. Version assets `?v=<hash>` to prevent stale JS after deployment.
