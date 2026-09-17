# HTMX UI Architecture

Fragment architecture, the event contract, and ten conventions each traced to a real shipped bug. Attribute mechanics (swap strategies, core attributes) live in `lang-html` `references/htmx.md`; this file owns the UI architecture and the pitfalls.

## The fragment is the unit

1. **One fragment = one route.** Every HTMX interaction returns a self-sufficient fragment served by its own URL (`/htmx/*`, `/modal/*`, `/form/submit/*`).
2. **The handler chooses full layout vs fragment** based on the `HX-Request` header (a shared `serveHTMX` helper). Never two handlers for the same view.
3. **Presenter mandatory**: Domain → ViewModel → template. Templates loop and branch; they never see a domain object. Views live in their own package (`internal/api/views/`).
4. **Dependency direction**: handler → service → repository. A service never imports `net/http` or `html/template` (guard it with a `go list` test).
5. **Route groups by auth level**, declared in one place (`routes.go`).
6. **Explicit business actions**: `Send Quote`, `Issue Invoice`, `Toggle`; not a raw `PATCH` on a status field. Each transition emits a traceable event (append-only `activities` / `event_logs` table) that feeds timelines and KPIs. Snapshot human labels into the event details **before** a deletion, or the activity feed ends up showing "deleted object: id:42".
7. **Bound every list** rendered without pagination (server cap, for example 500 rows, with a truncation flag). An unbounded list always ends up blowing the DOM.

## HX-Trigger event contract (mandatory)

Every mutation handler emits an `HX-Trigger` header named entity + verb (`taskUpdated`, `projectDeleted`). The canonical names live in one Go constants file; never inline string literals, so a rename cannot silently break listeners.

Every list container that renders entity rows subscribes to **all** events that entity emits:

```html
hx-trigger="load once, taskUpdated from:body, taskCompleted from:body, taskDeleted from:body"
```

- The page scaffold **ships with** these triggers; otherwise every new page is born "stale on mutate". A missing listener is the most common source of "I created it but the list did not refresh".
- CI runs a test that fails when a handler emits an event with no subscriber.
- Adding an event: constant first, use it in the emitting handler, add `<event> from:body` to every container that should refresh, run the coupling test.

## Ten gotchas (each one is a past incident)

1. **Never answer `204` on a swap.** HTMX skips the swap on 204: the deleted card stays in the DOM. Answer `200` + empty body (+ `HX-Trigger`).
2. **`HX-Location` discards the response body**: a modal-close script embedded in the success fragment never executes. Close the modal explicitly on the trigger side.
3. **`hx-ext="json-enc"` serializes everything as strings**, including numeric `<select>`s. Input DTOs use `*string` + `strconv`; a `*int` field means 400.
4. **Field naming is a contract**: `project_ids` (plural, aggregated) vs `project_id`. Normalize one-value-to-slice with a shared helper; never expose the same field under two names in different modals.
5. **File downloads never go through `hx-get`.** `Content-Disposition` is only honored by a navigation; use `<a href="..." download>`. The zero-results path returns a valid empty document, not a retargeted toast.
6. **A relative or empty `hx-get` (`?period=...`) resolves to the current URL**: the full page comes back and `outerHTML`-swaps into the card, giving an exponential load loop. Always guard the loading skeleton with the fragment-path conditional (`{{ if .HTMXPath }}`).
7. **Re-initialize JS widgets on `htmx:afterSwap`** (pickers, chips, popovers): a single `DOMContentLoaded` hook does not survive swaps.
8. **Authenticated pages: `Cache-Control: no-store`.** Otherwise the browser serves the cached full-page response to an HTMX request and it swaps whole into `#main-content`.
9. `stopPropagation()` + `preventDefault()` on any action button living inside a `<summary>` (otherwise clicking it folds the `<details>`).
10. **Version the assets** (`?v=<hash>`). After a deploy behind a caching proxy, fresh HTML wired to stale JS reads as "the button does nothing".
