# CUBE CSS Reference

CUBE CSS = **C**omposition **U**tility **B**lock **E**xception

Source: https://cube.fyi

---

## Layer 1: Composition

Composition classes handle layout and flow. They are high-level, reusable, and concern themselves with **space between things** not the things themselves.

```css
/* Stack: vertical flow with consistent gap */
.stack {
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
}

.stack > * + * {
  margin-block-start: var(--stack-space, var(--space-s));
}

/* Override space on a specific stack */
.stack[data-space="l"] {
  --stack-space: var(--space-l);
}
```

Composition classes come from **Every Layout primitives** (see `every-layout.md`).

---

## Layer 2: Utility

Single-responsibility classes that apply one design token. Always use `!important` to win specificity battles — that is intentional.

```css
.text-step-0  { font-size: var(--step-0) !important; }
.text-step-1  { font-size: var(--step-1) !important; }
.weight-bold  { font-weight: var(--font-weight-bold) !important; }
.color-accent { color: var(--color-accent) !important; }
.bg-surface   { background: var(--color-surface) !important; }
.flow > * + * { margin-block-start: var(--flow-space, var(--space-s)); }
```

### Naming convention

`{property}-{token}` — e.g., `text-step-2`, `bg-base`, `color-muted`, `radius-m`.

Utilities are generated from your design token scale, not invented per component.

---

## Layer 3: Block

Block styles are scoped to a component. One class, one component.

```css
/* Block: .card */
.card {
  border-radius: var(--radius-m);
  background: var(--color-surface);
  padding: var(--space-m);
}

.card__title {
  font-size: var(--step-1);
  font-weight: var(--font-weight-bold);
}
```

Rules:
- Block selectors are flat (`.card`, `.card__title`) — no nesting beyond one level
- Block does **not** set margin or position — that is the composition layer's job
- Use BEM-style element names only when needed; avoid them for simple components

---

## Layer 4: Exception

Exceptions modify a block's appearance using `data-*` attributes. They override specific properties for a variant.

```html
<article class="card" data-variant="featured">...</article>
<nav class="nav" data-layout="horizontal">...</nav>
```

```css
.card[data-variant="featured"] {
  background: var(--color-accent);
  color: var(--color-accent-fg);
}

.nav[data-layout="horizontal"] {
  flex-direction: row;
}
```

Rules:
- Exceptions use `data-*` selectors, never modifier classes (`card--featured`)
- Keep exceptions minimal — if you have many, the block design needs rethinking
- Document `data-*` values in comments or a component README

---

## Design Tokens

CUBE CSS relies on a custom property token system. Define at `:root`:

```css
:root {
  /* Space scale (fluid or stepped) */
  --space-3xs: clamp(0.25rem, 0.23rem + 0.11vw, 0.31rem);
  --space-2xs: clamp(0.5rem, 0.46rem + 0.22vw, 0.63rem);
  --space-xs:  clamp(0.75rem, 0.69rem + 0.33vw, 0.94rem);
  --space-s:   clamp(1rem, 0.91rem + 0.43vw, 1.25rem);
  --space-m:   clamp(1.5rem, 1.37rem + 0.65vw, 1.88rem);
  --space-l:   clamp(2rem, 1.83rem + 0.87vw, 2.5rem);
  --space-xl:  clamp(3rem, 2.74rem + 1.3vw, 3.75rem);

  /* Type scale */
  --step--1: clamp(0.8rem, 0.78rem + 0.11vw, 0.88rem);
  --step-0:  clamp(1rem, 0.96rem + 0.22vw, 1.13rem);
  --step-1:  clamp(1.25rem, 1.19rem + 0.33vw, 1.5rem);
  --step-2:  clamp(1.56rem, 1.5rem + 0.33vw, 1.88rem);
  --step-3:  clamp(1.95rem, 1.84rem + 0.54vw, 2.38rem);

  /* Colors */
  --color-text: #1a1a2e;
  --color-surface: #ffffff;
  --color-accent: #4361ee;
  --color-accent-fg: #ffffff;
  --color-muted: #6b7280;

  /* Misc */
  --radius-s: 0.25rem;
  --radius-m: 0.5rem;
  --radius-l: 1rem;
}
```

Use [Utopia](https://utopia.fyi) to generate fluid type and space scales.

---

## Class Order on HTML Elements

```html
<!-- composition → utility → block → exception data attribute -->
<article class="box stack color-muted card" data-variant="featured">
```

Order: composition primitives first, utilities second, block name last, exceptions as `data-*`.
