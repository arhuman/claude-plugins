# Component Rules

Project-local class conventions override these defaults.

## Active state: ARIA, never a class

Toggle buttons: `aria-pressed="true"`; navigation/filter links: `aria-current="page"`. Never `--active`/`--selected` classes. Where native state exists (`:has(:checked)`), it alone drives visuals; secondary tracking may use differently named `data-*`, never visual selectors.

## Buttons

Always include `btn` plus modifier:

| Modifier | Use |
|----------|-----|
| `btn--primary` | Dominant CTA/submit |
| `btn--secondary` | Cancel/dismiss/paired secondary |
| `btn--ghost` | Low-emphasis action/nav |
| `btn--danger` | Destructive, with `hx-confirm` |
| `btn--sm`, `btn--lg`, `btn--block` | Dense toolbar, hero CTA, full-width footer |

Icon-only: separate `.btn-icon` with `title` + `aria-label`. Quick picks use `.b-chip`, not small secondary buttons.

## Forms

- One architecture: `b-form__group`, `b-form__legend`, `b-form__field`; `form-input` for input/textarea, `form-select` for select.
- Start from `templates/_scaffold/`; create/edit share a field partial. Normalize defaults in shared command (`runCreateX`), not handlers.
- Order title, description, secondary fields; frequent fields visible, rare fields in `<details>`.
- Complex pickers: searchable entity popover with inline creation, state segments/dots, priority radio pills, tag chips.
- Child modals show parent chain first; absent parent uses danger-toned “no parent linked yet”.

### Validation states

`aria-invalid="true"` drives danger-token border; linked error text uses `role="alert"`. `data-valid="true"` shows subtle success glyph without border change. Never `alert()` or inline red styles. Apply `../../lang-html/references/accessibility.md` for error linkage/focus.

### Interactive states (mandatory on every interactive element)

Every button/link/input/select/textarea: visible `:hover`, token-ring `:focus-visible`, pressed translate/brightness `:active`, and reduced-opacity/not-allowed `:disabled` or `[aria-disabled="true"]`.

## Modals

- Body: `overflow-x: hidden; overflow-y: auto`, cap `min(90dvh, ...)`; never `overflow: hidden`.
- One open modal; stable normalized field IDs (`task-form-*`). Submit immediately closes modal or disables button.
- Root carries modal class only; overlay owns dismissal.
- Narrow data structs; inherit parent theme, no speculative `BaseModalData`. Generalize after 3 real cases.

## One surface owner per region

Never nest background + padding + border owners. Wrapper around a complete card becomes `padding: 0; background: transparent; border: 0`.

## Tables

Ship block styles and mobile behavior: internal `.table-wrap`, `minmax(0, 1fr)` track; at ≤ 640px rows become cards with `data-label` + `::before` labels.

## Empty states

No sample: sentinel `—` and empty unit key, tested in template; never a misleading zero such as `0m`.

## Animations and transitions

- `animation-fill-mode: backwards`, never `both` (persistent stacking context).
- Token durations/easing; honor global `prefers-reduced-motion` in `tokens.css`, no per-component bypass.
- One partial and consistent markup per component; use element-agnostic child selectors (`> :where(div, li)`).
- Desktop/mobile nav loop over one item source.
