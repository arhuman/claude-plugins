---
name: lang-html
description: 'HTML, HTMX and CSS mechanics using CUBE CSS and Every Layout. Use for templates, partial updates, styles and server-rendered components. For visual identity and screen quality use `design-system`.'
---
# lang-html

## Reference Guide

Load by task: `references/cube-css.md` for CSS/cascade/naming; `references/every-layout.md` for layout; `references/htmx.md` for partial requests/swaps/events; `references/accessibility.md` for ARIA/forms/keyboard/focus.

## Core Philosophy

Semantic HTML first, CSS enhancement, HTMX progressive interaction with no-JS fallbacks. Use the cascade and composable layout primitives.

## CSS Architecture: CUBE CSS

Classes in order: composition (layout), utility (one token), block (component), exception (`data-*` variant). For design-system projects load its CSS contract for file order, tokens and native/ARIA state precedence.

## Every Layout: Use These Primitives

Use the reference implementations, not ad-hoc layout: `.stack` vertical flow; `.box` padded region; `.center` bounded centering; `.cluster` wrapping groups; `.sidebar` fixed/fluid columns; `.grid` intrinsic grid; `.frame` aspect ratio; `.reel` horizontal scroll; `.icon` SVG/text sizing.

## MUST DO

- Semantic landmarks; custom-property spacing/color/type.
- Block CSS scoped to one role class; variants via `data-*`, not `card--dark`.
- Prefer `gap` for sibling spacing; compose Every Layout in HTML.
- Start with container `hx-boost` for descendant links/forms; add element attributes only when needed. Verify every `hx-target` exists.

## MUST NOT

- Inline styles except generated/dynamic values unavailable in CSS.
- Layout-spacing utilities, block nesting beyond one level, or `!important` outside intentional utilities.
- Appearance-encoded names (`red-text`, `big-button`), HTMX without no-JS fallback, or `outerHTML` swapping the request trigger.
