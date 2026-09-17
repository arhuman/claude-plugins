# Accessibility and i18n

Contracts, not intentions: each rule is measured by an audit or a test.

## Accessibility

### Contrast (WCAG 2.1 AA, measured)

- Normal text ≥ 4.5:1, large text ≥ 3:1, active UI components and icons ≥ 3:1.
- Ratios are **measured and documented in comments next to the tokens** for every critical pair of every theme, and enforced by a contrast audit plus axe-core in Playwright, with a ratchet matrix.

### Targets and names

- Touch targets ≥ 44 px, via a token (`--touch-target-min: 2.75rem`), with a dedicated Playwright spec.
- **Every icon button has an accessible name** (`aria-label`, `aria-labelledby`, or visible text). Audited, ratcheted downward over time.

### Focus and landmarks

- `:focus-visible` styled globally and visible everywhere.
- `skip-link` to `#main-content`; `<main tabindex="-1">` so the skip target can take focus.
- `aria-current="page"` on the active nav item; `aria-label` on every `<nav>` and every `role="search"`.

### Horizontal overflow is an a11y bug

- A `position: fixed` element off-viewport is **not** clamped by `overflow-x: clip` on `html/body`. A closed drawer is `display: none`, not translated off-screen. Verify `documentElement.scrollWidth` in a test.
- `body { overflow-x: clip }`, not `hidden` (hidden breaks `position: sticky`).
- Grid tracks: `minmax(0, 1fr)`, never bare `1fr` (auto min-width overflows to the right as soon as a wide child arrives).

## i18n

- **Multilingual by default**, with one base locale as fallback. No visible hardcoded string anywhere: not in templates, not in JS, not in an AI prompt, not in an `aria-label`. A test must fail when a template contains a visible literal string; golden snapshots **per template AND per locale**.
- The locale travels via `context.Context` server-side; labels needed by JS are exposed as `data-i18n-*` attributes on `<body>`.
- **One locale store**: if the UI keeps it in a cookie, persist it in the database too; otherwise everything that runs outside a request (rule engines, emails, jobs) falls back to the default language.
- Public and auth pages go through the **locale-aware** renderer (not the default one) and expose the current locale to the view; otherwise the language toggle points at itself.
- **Versioned glossary** (`docs/VOCABULARY.md`): canonical UI terms, synonyms allowed only in listed contexts (marketing), a dedicated lint, and the glossary updated in the same PR as the term.
- First occurrence of a domain term gets a short inline definition (a `help-tip` component) with an **edge-aware** popover (flips `data-align="end"` near the viewport edge).
- Docs and ADRs are written in English even when the conversation and plan are in French.
