# CSS Contract

## Layers, in this exact order

```
tokens.css       custom properties in :root + media/theme scopes only
composition.css  Every Layout primitives; layout only, no color/type
blocks/NNN-*.css named .b-* blocks; concatenate into blocks.css
utilities.css    single-responsibility utilities
```

Author blocks in 50-900-line numbered sections; never edit generated `blocks.css`. Keep `!important` primitives last in concatenation. Small products may use one no-build file (tokens/reset/primitives/blocks), preserving layer order.

## Tokens

- Define every `var(--x)` under the CSS directory; token audit exceptions need commented allowlists (primitive parameters, runtime/theme-scoped values).
- No color literals outside `tokens.css`; ratchet existing debt, fail additions.
- Token spacing/radii, never hard `style=` values. Fluid `clamp()` type `--step--2` through `--step-4`, no text-size breakpoints.
- Prefer semantic aliases (`--space-standard`, `--gap-tight/normal/section`, `--radius-btn`). Use 4px spacing grid and one named z-index scale; no numeric z-index elsewhere.
- Define derived `color-mix()` dim/glow tokens once in `tokens.css`.

## Canonical semantic token vocabulary

New/generated code uses these names verbatim, by intent not hue:

```css
--bg-base --bg-surface --bg-elevated
--border-subtle --border-strong
--text-primary --text-secondary --text-muted --text-inverse
--accent --accent-hover --accent-soft --on-accent
--ok --ok-soft --warn --warn-soft --danger --danger-soft
--space-3xs --space-2xs --space-xs --space-s --space-m --space-l --space-xl --space-2xl
--radius --radius-lg --radius-pill
--shadow-1 --shadow-2
--dur-fast --dur-base --dur-slow --ease-standard
--focus-ring --tap-min /* 44px minimum interactive smaller axis */
--z-dropdown --z-sticky --z-modal --z-toast
--break-phone: 640px --break-tablet: 880px --break-wide: 1180px
```

Existing repos add aliases in `tokens.css` (e.g. `--bg-surface: var(--panel)`), never rename existing tokens wholesale. New code uses canonical names; migration debt goes to backlog. Never alias a token to itself (cycle).

## Breakpoints

`--break-*` in `tokens.css` is the audited allowlist; media queries use literals because custom properties cannot supply query values. Desktop-down `max-width` only:

| Name | Value | Reflow |
|------|-------|--------|
| phone | ≤ 640px | Dense rows/gutters |
| tablet | ≤ 880px | Side rail -> top bar + drawer |
| wide | ≤ 1180px | Columns -> stack |

No fourth value without ADR. Prefer switcher, auto-fit grid and `clamp()` over queries. One small-screen drawer for all themes, in one file.

## Themability

Components work without a theme attribute. Reskins change tokens and scoped chrome only, not component structure or templates.

- Server injects `<html data-theme>`. JS may persist choice (cookie/localStorage fallback), never tokens or first-render attribute; do not read theme client-side.
- Token overrides only in `tokens.css` theme scopes.
- Themes own chrome/voice (background, border, radius, font, color, motion), never structure (position, clearance, collapse). Audit structural redeclarations.
- One template for all skins.

### Theme override rules (apply to any scope, including plain dark mode)

- Background changes also redeclare color.
- `color-mix()` percentages stay in [0%, 100%].
- Prefer `background-image` + `background-color` longhands for independent fallback.
- Validate overrides in light and dark.

### Scaling note: multiple simultaneous variants

After a second real structural variant, use the project's design-system skill: one server-side variant registry, base/variant-delta/primitives zones, `!important` primitives (legacy unlayered CSS outranks `@layer`) and redeclaration audit. Do not add this machinery speculatively.

## Presentation security and performance

- CSP `style-src 'self'; font-src 'self'`; self-host woff2, split `unicode-range`, `font-display: swap`.
- No inline styling except ratcheted primitive parameters such as `--stack-space`.
- Server versions local assets `?v=<content-hash>`; no third-party calls on authenticated pages.
- Auth responses: `Cache-Control: no-store`; load `htmx-ui.md` for swap implications.
