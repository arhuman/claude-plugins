---
name: lang-html
description: HTML, HTMX, and CSS best practices following CUBE CSS methodology and Every Layout primitives. Use when working with HTML templates, HTMX interactions, CSS styling, or building server-rendered UI components.
---

# lang-html

This skill defines rules for writing maintainable, progressively enhanced HTML with CUBE CSS and Every Layout.

## Reference Guide

Load the relevant reference when the task involves:

| Topic | File | Load When |
|-------|------|-----------|
| CUBE CSS | `references/cube-css.md` | writing or reviewing CSS, class naming, cascade decisions |
| Every Layout | `references/every-layout.md` | layout primitives: stack, cluster, sidebar, grid, center, box |
| HTMX | `references/htmx.md` | HTMX attributes, partial rendering, swap strategies, events |

## Core Philosophy

- HTML is the foundation. CSS enhances. HTMX progressively adds interactivity.
- Prefer semantic HTML over `<div>` soup.
- The cascade is a feature — use it, don't fight it.
- Layouts are solved with composable primitives (Every Layout), not one-off utilities.

## CSS Architecture: CUBE CSS

Structure all CSS in four layers:

1. **Composition** — layout primitives (`.stack`, `.cluster`, `.sidebar`, `.grid`, `.center`, `.box`)
2. **Utility** — single-purpose design tokens (`.text-step-1`, `.bg-surface`, `.color-accent`)
3. **Block** — component-scoped styles (`.card`, `.nav`, `.hero`)
4. **Exception** — overrides using `data-*` attributes (`[data-variant="inverted"]`)

Apply classes in that order: composition first, utilities second, blocks third, exceptions last.

## Every Layout: Use These Primitives

Do not write ad-hoc layout CSS. Use these intrinsic primitives:

| Primitive | Use for |
|-----------|---------|
| `.stack` | Vertical spacing between siblings |
| `.box` | Padding + optional border for a contained region |
| `.center` | Horizontal centering with max-width |
| `.cluster` | Wrapping flex groups (tags, buttons, nav items) |
| `.sidebar` | Two-column layout with one fixed-width side |
| `.grid` | Auto-responsive grid without media queries |
| `.frame` | Fixed aspect-ratio media containers |
| `.reel` | Horizontal scrolling rows |
| `.icon` | Inline SVG icon with text sizing |

See `references/every-layout.md` for CSS implementations.

## MUST DO

- Use semantic HTML elements (`<nav>`, `<main>`, `<article>`, `<section>`, `<aside>`, `<header>`, `<footer>`)
- Define spacing, color, and typography via custom properties (`--space-s`, `--color-text`, `--step-0`)
- Use `data-*` attributes for state/variant exceptions, not modifier classes (`card--dark`)
- Use `hx-boost` on `<a>` and `<form>` elements before reaching for more specific HTMX attributes
- Scope block CSS to a single class selector matching the HTML element's role
- Write layout CSS using `gap`, not `margin` between siblings
- Validate that HTMX targets exist on the page before wiring `hx-target`

## MUST NOT

- Write inline styles (except generated/dynamic values that cannot be in CSS)
- Use utility classes for layout spacing — use Every Layout primitives instead
- Nest block selectors more than one level deep
- Use `!important` except in utility classes (where it is intentional)
- Use class names that encode visual appearance (`red-text`, `big-button`) — use semantics or tokens
- Add HTMX attributes without defining a clear fallback for no-JS environments
- Use `hx-swap="outerHTML"` on the element that triggers the request (causes self-deletion)
