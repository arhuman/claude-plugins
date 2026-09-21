# CUBE CSS Reference

CUBE = Composition, Utility, Block, Exception. Source: https://cube.fyi

## Layer 1: Composition

Reusable layout/flow between elements; use implementations in `every-layout.md`, not component positioning. Stack spacing may be overridden by `data-space` setting `--stack-space`.

## Layer 2: Utility

One token, one responsibility; intentional `!important` wins specificity:

```css
.text-step-0 { font-size: var(--step-0) !important; }
.weight-bold { font-weight: var(--font-weight-bold) !important; }
```

### Naming convention

`{property}-{token}` (`text-step-2`, `bg-base`, `color-muted`); derive from token scale, not per component.

## Layer 3: Block

One component class; flat selectors (`.card`, `.card__title`), at most one nesting level. No margin/position (composition owns those). BEM elements only when needed. Component colors, padding, radius and type reference tokens.

## Layer 4: Exception

Minimal `data-*` variants, never modifier classes. Document allowed values in comments/component README; many exceptions require redesign.

```html
<article class="card" data-variant="featured">...</article>
```

```css
.card[data-variant="featured"] {
  background: var(--accent);
  color: var(--on-accent);
}
```

For native/ARIA interactive states in design-system projects, load `../../design-system/references/components.md`; native state takes precedence over variant attributes.

## Design Tokens

Define custom properties at `:root` for fluid/stepped spacing, fluid type, semantic colors and radii. Generate fluid scales with [Utopia](https://utopia.fyi). For design-system work, load `../../design-system/references/css-contract.md` for canonical vocabulary, aliases, theme scopes, audited literals and file order; do not introduce a parallel dialect.

## Class Order on HTML Elements

Composition first, utility second, block last; exceptions as attributes:

```html
<article class="box stack color-muted card" data-variant="featured">
```
