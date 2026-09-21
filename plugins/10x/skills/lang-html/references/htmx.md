# HTMX Reference

Targets **htmx 2.x**. Source: https://htmx.org/docs

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
innerHTML  : replace inner HTML of target (default)
outerHTML  : replace the target element itself
beforebegin: insert before target
afterbegin : prepend inside target
beforeend  : append inside target
afterend   : insert after target
delete     : delete target, ignore response
none       : no DOM change (side-effect requests)
```

**Warning**: never use `outerHTML` on the element that issued the request: it deletes itself before the swap completes.

---

## Common Patterns

### Lazy-load a section

Use fragment URL, `hx-trigger="load"`, `hx-swap="innerHTML"`, and existing polite loading region.

### Infinite scroll

Next-page row: `hx-trigger="revealed"`, `hx-swap="afterend"`, `hx-target="this"`; request the next page and announce loading.

### Active search

Search input `name="q"`, `hx-get="/search"`, `hx-trigger="input changed delay:300ms, search"`, `hx-target="#results"`, `aria-controls="results"`; existing results region `aria-live="polite"`.

### Form with validation feedback

Put `hx-post` on the form, target existing assertive feedback region, label controls and use native constraints plus server validation. Load `accessibility.md` for linked errors/focus.

### Optimistic UI with `hx-swap-oob`

Return secondary fragments with matching IDs and `hx-swap-oob="innerHTML"` alongside the primary fragment.

### Loading indicator

Point `hx-indicator` at an `aria-hidden="true"` spinner with class `htmx-indicator`:

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

- Apply `accessibility.md` for existing live regions, busy state and post-swap focus
- Use `hx-boost="true"` on `<main>` or `<nav>` before adding individual `hx-get` attributes
- Return only the fragment HTML for HTMX requests; return the full page otherwise (check `HX-Request` header)
- Use `hx-indicator` for any request taking > 200ms
- Prefer `hx-trigger="submit"` on `<form>` over `hx-post` on the submit button
- Use `hx-push-url="true"` for navigations that deserve a bookmark/back-button entry

## MUST NOT

- Use `hx-swap="outerHTML"` on the element issuing the request
- Embed business logic in `hx-vals`: keep that on the server
- Rely on HTMX for form validation: use native HTML5 constraint validation + server-side
- Use `hx-trigger="every 1s"` for polling without a termination condition (`hx-trigger="every 5s [document.hasFocus()]"`)
- Skip the no-JS fallback for critical interactions: `<a href="/page">` degrades gracefully, `<div hx-get="/page">` does not
