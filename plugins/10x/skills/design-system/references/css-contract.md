# CSS Contract

Layer order, token rules, breakpoints, theme scoping, and presentation-layer security. Every rule here traces to a production decision or a shipped bug.

## Layers, in this exact order

```
tokens.css        Layer 0: custom properties only (:root + theme overrides)
composition.css   Layer C: Every Layout primitives (wrapper stack cluster switcher grid sidebar box)
blocks/NNN-*.css  Layer B: named blocks (.b-*), concatenated into blocks.css by the build
utilities.css     Layer U: single-responsibility utilities
```

- `tokens.css` contains **no rules** outside `:root` and media/theme scopes.
- `composition.css` is pure layout: no color, no typography.
- Blocks are authored in numbered section files (50 to 900 lines each); the concatenated `blocks.css` is a **build artifact**. Editing it by hand is a fault caught by the build-verify audit.
- The primitives file (`!important` rules) stays **last** in concatenation order: that is what prevents a theme scope from breaking a primitive.
- Small products may use one assumed mono-file (tokens + reset + primitives + blocks, no build); the layer order still applies inside the file.

Why: authoring against a 7200-line monolith produced cascade conflicts, accidental specificity, and untraced regressions across 9 themes.

## Tokens

- Every `var(--x)` must have a `--x:` definition somewhere under the CSS directory. An undefined token silently falls back to the UA default: invisible in CI, visible to the user. Enforced by a token audit with an explicit, commented allowlist (primitive parameters passed via `style="--stack-space: ..."`, runtime values, theme-scoped tokens).
- **Zero color literals** (`#hex`, `rgb()`, `hsl()`, named colors) outside `tokens.css`. Ratchet: existing occurrences tolerated, any addition fails.
- Spacing and radii always via tokens, never a hard value in a `style=` attribute.
- Typography scale is **fluid via `clamp()`** (`--step--2` through `--step-4`): no breakpoint for text size.
- Prefer semantic aliases over numeric primitives in new components: `--space-standard` over `--space-4`, plus `--gap-tight` / `--gap-normal` / `--gap-section`, `--radius-btn`.
- 4 px spacing grid. One named z-index scale (`--z-dropdown` ... `--z-toast`); no numeric `z-index` anywhere else.
- Derived tokens computed via `color-mix()` (dim/glow variants) are defined once in `tokens.css`; never redefine them downstream.

## Canonical semantic token vocabulary

One naming contract across every project, so a block generated for one repo drops into another unchanged. Three production repos grew three dialects for the same concepts (`--bg-base` / `--color-bg` / `--ink`); the divergence bought nothing and costs portability, so the vocabulary is now fixed.

Names carry **intent, never hue**: a token named `--amber` breaks the day a theme needs it blue.

```css
/* surfaces and borders */
--bg-base --bg-surface --bg-elevated
--border-subtle --border-strong

/* text */
--text-primary --text-secondary --text-muted --text-inverse

/* intent */
--accent --accent-hover --accent-soft --on-accent
--ok --ok-soft  --warn --warn-soft  --danger --danger-soft

/* spacing: 4px grid, T-shirt scale */
--space-3xs --space-2xs --space-xs --space-s --space-m --space-l --space-xl --space-2xl

/* shape and depth */
--radius --radius-lg --radius-pill
--shadow-1 --shadow-2

/* motion */
--dur-fast --dur-base --dur-slow --ease-standard

/* focus, touch, layers */
--focus-ring
--tap-min            /* 44px; smaller axis of every interactive element */
--z-dropdown --z-sticky --z-modal --z-toast

/* breakpoints: documentation and audit source, see below */
--break-phone: 640px  --break-tablet: 880px  --break-wide: 1180px
```

- The `--break-*` tokens are the single written source for the breakpoint allowlist. `@media` cannot read a custom property: media queries still write the literal value, and the audit checks the literal against this list.
- New projects and all generated code use these names verbatim.
- **Existing repos migrate via an alias layer, never a rename.** A short block in `tokens.css` maps the canonical names onto the local dialect; old code keeps its names, new code uses the canonical ones, and the rename itself is ordinary conformance debt (backlog phases):

```css
/* alias layer: canonical := local dialect (example from a repo using --panel/--ink) */
:root {
  --bg-base: var(--bg);  --bg-surface: var(--panel);  --bg-elevated: var(--panel-2);
  --text-primary: var(--ink);  --text-secondary: var(--muted);  --text-muted: var(--faint);
  --border-subtle: var(--border);
  --accent-hover: var(--accent-hover-local);
}
/* a canonical name the dialect already uses (--ok, --warn) needs no alias:
   aliasing a token to itself is a reference cycle and invalidates it */
```

## Breakpoints

One canonical set of **three values**, single documented source in `tokens.css`, allowlist enforced by an audit. Media queries are written desktop-down with `max-width`: base rules are the desktop layout, smaller screens carve overrides off it.

| Name | Value | Reflow at this point |
|------|-------|----------------------|
| phone | `≤ 640px` | dense rows reflow, gutters tighten |
| tablet | `≤ 880px` | side rail becomes top bar + hamburger drawer |
| wide | `≤ 1180px` | wide multi-column collapses to stacked |

- Never `768px`, `900px`, `1024px`, `47rem`, or any other value. Adding a fourth breakpoint requires an ADR first.
- One small-screen navigation for **all** themes (a single drawer), defined in a single file.
- Media queries are a last resort: `switcher`, `grid auto-fit`, and `clamp()` cover most cases with no breakpoint at all.

## Themability

The portable constraint: **a re-skin is an orthogonal change.** Every component renders correctly with no theme attribute set, and changing the look (dark mode, a client brand, a seasonal skin) touches only token overrides plus small scoped chrome deltas: never the component rules themselves. If a restyle forces you to edit a block file, the block was leaking hardcoded decisions that belonged in tokens.

- Theme on `<html data-theme>`, **injected server-side**. JS only persists the user's choice (cookie or `localStorage` fallback), never the tokens, and never sets the attribute on first render.
- Theme token overrides live only in `tokens.css` under the scoped selector. When every color, font, radius, and duration in components goes through a token, most re-skins are a token-block swap and nothing else.
- A theme scope may override **chrome and voice**: background, border, radius, font, color, motion speed. It never redeclares **structure**: positioning, padding clearance, responsive collapse. Structural rules are theme-independent by definition; a scope that touches them is a bug an audit should catch (each time a scope silently redefined structure, the same layout bug shipped once per theme).
- Never duplicate a template per theme; one template serves all skins.

### Theme override rules (apply to any scope, including plain dark mode)

- Any override that changes `background` **must** redeclare `color`: the base `color` was tuned for the base background, and the required contrast changed.
- `color-mix()` percentages stay within `[0%, 100%]`. An out-of-range value silently invalidates the whole declaration: no error, no fallback, just transparent.
- Prefer `background-image` + `background-color` longhands over the `background` shorthand: the shorthand resets all sub-properties and one invalid sub-expression kills the whole declaration; longhands fail independently.
- Validate every override in light **and** dark theme: backgrounds and accents differ significantly, and correct-in-dark can be invisible-in-light.

### Scaling note: multiple simultaneous variants

If a product ships several structural look-and-feel variants at once (as Asheeve does with personalities), the simple contract above needs machinery: a single server-side registry of the variant list that every consumer derives from, a base / variant-delta / primitives three-zone model (`!important` primitives, because unlayered legacy CSS outranks every `@layer`), and a redeclaration audit. That machinery is deliberately **not** part of this skill's defaults: reach for it after the second real variant, not preemptively, and follow the project's own design-system skill (for example `asheeve-design-system`) where it exists.

## Presentation security and performance

- Strict CSP: `style-src 'self'; font-src 'self'`. Consequences: **self-hosted fonts** as woff2 with split `unicode-range` and `font-display: swap`; no inline `style` for styling (one more reason for the utility layer; the only tolerated inline styles are primitive parameters like `--stack-space`, tracked by a ratchet).
- Local assets **versioned** (`?v=<content-hash>` injected by the server). Unversioned assets behind a long-lived proxy cache mean fresh HTML wired to stale JS after every deploy ("the button does nothing").
- No third-party calls from authenticated pages.
- Authenticated page responses: `Cache-Control: no-store` (see the HTMX reference for the swap bug this prevents).
