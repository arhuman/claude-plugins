# Accessibility

Server-rendered HTML with HTMX has a strong accessibility baseline: real links, real forms, full pages. The rules below keep it that way when adding partial updates. Target: WCAG 2.1 AA.

## Semantic structure

- One `<h1>` per page; heading levels never skip (h2 → h4 is a defect).
- Landmarks: one `<main>`, `<nav>` with `aria-label` when there are several, `<header>`/`<footer>`.
- Interactive = `<a href>` (navigation) or `<button>` (action). Never `<div hx-post>`: it has no keyboard support, no focus, no role. If HTMX is put on a non-interactive element, add `role`, `tabindex="0"` and key handling; better: don't.
- Every form control has a `<label for>`; group radios/checkboxes in `<fieldset><legend>`.

## HTMX partial updates

Swaps are invisible to screen readers unless announced, and they can strand focus:

- Wrap swap targets that convey results in a live region: `<div aria-live="polite">` (already-present region; inserting `aria-live` in the same swap does not announce). Use `role="status"` for confirmations, `role="alert"` only for errors.
- After a swap that replaces the element containing focus, move focus deliberately: `hx-swap="... focus-scroll:true"` or a small `htmx:afterSwap` handler that focuses the new region's heading (`tabindex="-1"` on it).
- Loading states: pair `hx-indicator` with `aria-busy="true"` on the target.
- Keep URLs honest: `hx-push-url` for navigation-like swaps, so back button and screen-reader page announcement work.

## Forms and errors

- Validation errors: `aria-invalid="true"` on the field, error text linked via `aria-describedby`, and the error summary in a `role="alert"` region focused after submit.
- Never rely on color alone for state; pair with text or an icon with `aria-hidden="true"` plus visible text.

## Keyboard and focus

- All functionality reachable by keyboard; test Tab / Shift-Tab / Enter / Escape on every new component.
- Visible focus style: never `outline: none` without an equal-or-better replacement (use `:focus-visible`).
- Modals: trap focus, Escape closes, focus returns to the trigger. Prefer `<dialog>`: it does this natively.

## Checks

- `axe-core` (or `@axe-core/playwright`) in E2E tests; zero violations on new screens.
- Quick manual pass: keyboard-only walk, 200% zoom, prefers-reduced-motion honored for HTMX transitions.
