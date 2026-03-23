# HTMX Reference

HTMX enables server-driven partial page updates via HTML attributes. It extends HTML — don't fight it.

Source: https://htmx.org/docs

---

## Core Attributes

| Attribute | Purpose |
|-----------|---------|
| `hx-get` / `hx-post` / `hx-put` / `hx-delete` / `hx-patch` | HTTP verb + URL |
| `hx-target` | CSS selector of element to update (default: triggering element) |
| `hx-swap` | How to swap the response into the target |
| `hx-trigger` | Event that fires the request (default: `click` for buttons, `submit` for forms) |
| `hx-boost` | Upgrade all `<a>` and `<form>` to AJAX in the subtree |
| `hx-push-url` | Update the browser URL bar |
| `hx-indicator` | CSS selector of element to show/hide during request |
| `hx-select` | Pick a fragment from the response by CSS selector |
| `hx-include` | Include values from other elements in the request |
| `hx-vals` | Add extra JSON values to the request |

---

## Swap Strategies

```
innerHTML   — replace inner HTML of target (default)
outerHTML   — replace the target element itself
beforebegin — insert before target
afterbegin  — prepend inside target
beforeend   — append inside target
afterend    — insert after target
delete      — delete target, ignore response
none        — no DOM change (side-effect requests)
```

**Warning**: never use `outerHTML` on the element that issued the request — it deletes itself before the swap completes.

---

## Common Patterns

### Lazy-load a section

```html
<div hx-get="/dashboard/stats" hx-trigger="load" hx-swap="innerHTML">
  <p aria-live="polite">Loading…</p>
</div>
```

### Infinite scroll

```html
<tbody id="rows">
  <!-- rows -->
  <tr hx-get="/rows?page=2" hx-trigger="revealed" hx-swap="afterend" hx-target="this">
    <td colspan="4">Loading more…</td>
  </tr>
</tbody>
```

### Active search

```html
<input
  type="search"
  name="q"
  hx-get="/search"
  hx-trigger="input changed delay:300ms, search"
  hx-target="#results"
  hx-swap="innerHTML"
  placeholder="Search…"
  aria-controls="results"
/>
<ul id="results" aria-live="polite"></ul>
```

### Form with validation feedback

```html
<form hx-post="/signup" hx-target="#form-feedback" hx-swap="innerHTML">
  <div class="stack">
    <label for="email">Email</label>
    <input id="email" name="email" type="email" required />
  </div>
  <div id="form-feedback" aria-live="assertive"></div>
  <button type="submit">Sign up</button>
</form>
```

### Optimistic UI with `hx-swap-oob`

Server can return multiple fragments. Out-of-band swaps update secondary targets:

```html
<!-- Server returns this in the response body -->
<li id="todo-123">Updated task</li>
<span id="todo-count" hx-swap-oob="innerHTML">5</span>
```

### Loading indicator

```html
<button hx-post="/process" hx-indicator="#spinner">
  Run
</button>
<span id="spinner" class="htmx-indicator" aria-hidden="true">Processing…</span>
```

```css
.htmx-indicator { display: none; }
.htmx-request .htmx-indicator,
.htmx-request.htmx-indicator { display: inline; }
```

---

## Request Headers HTMX Sends

| Header | Value |
|--------|-------|
| `HX-Request` | `"true"` |
| `HX-Trigger` | ID of triggering element |
| `HX-Target` | ID of target element |
| `HX-Current-URL` | Current browser URL |
| `HX-Boosted` | `"true"` if boosted request |

Use `HX-Request` on the server to return partial HTML vs full page.

---

## Response Headers Server Can Send

| Header | Effect |
|--------|--------|
| `HX-Redirect` | Redirect browser to URL |
| `HX-Refresh` | Force full page refresh |
| `HX-Retarget` | Override `hx-target` for this response |
| `HX-Reswap` | Override `hx-swap` for this response |
| `HX-Push-Url` | Push URL to history |
| `HX-Trigger` | Fire client-side events after swap |

---

## MUST DO

- Always pair `hx-target` with an `aria-live` region when updating content users need to notice
- Use `hx-boost="true"` on `<main>` or `<nav>` before adding individual `hx-get` attributes
- Return only the fragment HTML for HTMX requests; return the full page otherwise (check `HX-Request` header)
- Use `hx-indicator` for any request taking > 200ms
- Prefer `hx-trigger="submit"` on `<form>` over `hx-post` on the submit button
- Use `hx-push-url="true"` for navigations that deserve a bookmark/back-button entry

## MUST NOT

- Use `hx-swap="outerHTML"` on the element issuing the request
- Embed business logic in `hx-vals` — keep that on the server
- Rely on HTMX for form validation — use native HTML5 constraint validation + server-side
- Use `hx-trigger="every 1s"` for polling without a termination condition (`hx-trigger="every 5s [document.hasFocus()]"`)
- Skip the no-JS fallback for critical interactions — `<a href="/page">` degrades gracefully, `<div hx-get="/page">` does not
