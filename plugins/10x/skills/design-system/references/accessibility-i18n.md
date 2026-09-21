# Accessibility and i18n

## Accessibility

### Contrast (WCAG 2.1 AA, measured)

Normal text ≥ 4.5:1; large text, active UI/icons ≥ 3:1. Measure critical pairs in every theme; document beside tokens; enforce contrast audit + Playwright axe-core with ratchet matrix.

### Targets and names

Touch targets ≥ 44px via token (canonical `--tap-min`; existing `--touch-target-min: 2.75rem` may alias it), verified by Playwright. Every icon button has an accessible name; audit and reduce unnamed-button debt.

### Focus and landmarks

Global visible `:focus-visible`; skip-link to `#main-content`, `<main tabindex="-1">`; active nav `aria-current="page"`; label every nav/search landmark. For keyboard, forms and swap focus load `../../lang-html/references/accessibility.md`.

### Horizontal overflow is an a11y bug

Closed fixed drawers use `display: none`, not offscreen translation; test `documentElement.scrollWidth`. Body uses `overflow-x: clip`, not sticky-breaking `hidden`. Grid tracks use `minmax(0, 1fr)`, never bare `1fr`.

## i18n

- Multilingual with base-locale fallback; no visible literals in templates, JS, AI prompts or ARIA. Enforce template literal test and golden snapshots per template × locale.
- Server locale via `context.Context`; JS labels via body `data-i18n-*`.
- One locale store: cookie preference also persists in DB for jobs/emails/rule engines.
- Public/auth pages use locale-aware renderer and expose current locale.
- Versioned `docs/VOCABULARY.md`: canonical terms, context-limited synonyms (e.g. marketing), dedicated lint; update with first use in same PR.
- First domain-term occurrence gets inline `help-tip`; edge-aware popover flips `data-align="end"` near viewport edge.
- Docs/ADRs in English regardless of conversation language.
