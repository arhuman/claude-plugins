# Component Rules

Canonical writing rules for buttons, chips, forms, modals, tables, states, and animations. Class names below are the canonical defaults; a project-local design-system skill wins if it defines its own.

## Active state: ARIA, never a class

```html
<button class="b-chip" aria-pressed="true">...</button>   <!-- toggle -->
<a class="b-chip" aria-current="page">...</a>             <!-- filter / nav -->
```

| Element is a | Active signaled by |
|---|---|
| `<button>` (toggle) | `aria-pressed="true"` |
| `<a>` (navigation / filter) | `aria-current="page"` |

An `--active` / `--selected` class is **forbidden** (CI audit): theme scopes target the ARIA attribute with higher specificity and silently win, so the chip keeps its selected look while the underlying input is unchecked. Corollary: when a state has a native CSS representation (`:has(:checked)`), that representation is the **only** source of truth. If another concern needs to track selection, use a differently named `data-*` attribute and never gate visual styling on it.

## Buttons

Always include the base class; a modifier alone does not work: `class="btn btn--primary"`, never `class="btn--primary"`.

| Class | Use case |
|-------|----------|
| `btn--primary` | Main CTA, form submit: the screen's dominant action |
| `btn--secondary` | Cancel, dismiss, secondary paired with primary |
| `btn--ghost` | Low-emphasis nav, background action |
| `btn--danger` | Destructive; always pair with a confirm (`hx-confirm`) |
| `btn--sm` / `btn--lg` / `btn--block` | Dense toolbars / hero CTAs / full-width modal footers |

Icon-only buttons are a separate component (`.btn-icon`), not a `btn` modifier, and **always** carry an accessible name (`title` + `aria-label`). Quick-pick chips (durations, tags, filters) use `.b-chip`, never `btn--sm btn--secondary`.

## Forms

- **One form architecture per project**: `b-form__group` + `b-form__legend` + `b-form__field`; one control class set (`form-input` for input/textarea, `form-select` for select). Never mix a second pattern in.
- New files start from a **scaffold** (`templates/_scaffold/`), not from a copy of an existing page.
- Create and edit variants of one entity **share the field body** in a common partial. Two diverging modals means two design systems and every bug fixed twice.
- Default-value normalization lives in the **shared command** (`runCreateX`), not in each handler; otherwise onboarding creates objects that differ from the rest of the app.
- Reading order descends: title, description, secondary fields. Frequent things visible; rare things folded in a `<details>`.
- Prefer purpose-built controls over dumb `<select>`s for complex pickers: searchable popover for entity pickers (with inline "+ new"), segmented control with status dots for states, radio pills for priorities, chip input for tags.
- When creating or editing a child entity, surface the **parent chain** at the top of the modal (for example Vision → Objective → Project). Empty state: "no parent linked yet" in danger tone; this makes the no-orphan rule visible.

### Validation states

```html
<input type="text" class="form-input" aria-invalid="true" ...>
<span role="alert" class="b-form__error text-sm color-danger">Required field</span>
```

- `[aria-invalid="true"]` drives the error border via a danger token; `[data-valid="true"]` shows a subtle success glyph, no border change.
- **Never** `alert()` or `style="color: red"` for validation feedback.

### Interactive states (mandatory on every interactive element)

Every `button`, `a`, `input`, `select`, `textarea` ships all four:

- `:hover` visible change
- `:focus-visible` outline via the focus-ring token
- `:active` pressed feedback (small translate + brightness)
- `:disabled` / `[aria-disabled="true"]` reduced opacity + `cursor: not-allowed`

No component ships without all four.

## Modals

- Scrollable body: `overflow-x: hidden; overflow-y: auto` + block-size cap `min(90dvh, ...)`. Never `overflow: hidden`: the submit button gets clipped as soon as a folded section opens, especially with the mobile keyboard up.
- One modal open at a time, so field IDs are stable and normalized (`task-form-*`).
- Immediate feedback on submit (close the modal or disable the button): without visible feedback the user double-clicks and creates duplicates.
- Root element carries the modal class only; dismiss lives on the overlay element, never on the root.
- Keep modal data structs narrow: no preemptive `BaseModalData`; the fragment inherits theme context from the parent document. Generalize only after 3 real cases.

## One surface owner per region

Never nest two containers that each carry background + padding + border. The card-in-a-card (doubled spacing, parasite frame) is a recurring bug: if a panel wraps a complete card, the panel becomes a passthrough (`padding: 0; background: transparent; border: 0`).

## Tables

A table **always** ships its block style and its mobile behavior:

- An internal scrollable wrapper (`.table-wrap`, `minmax(0, 1fr)` grid track).
- At `≤ 640px`, each `<tr>` collapses into a card; labels are restored via `data-label` attributes + `::before`. Without this, the right-hand columns (badges, statuses) are invisible on phones.

## Empty states

Never render a zero-value where there is no sample (`0m` where nothing was measured). Convention: the sentinel character `—` with an empty unit key, tested in the template.

## Animations and transitions

- `animation-fill-mode: backwards`, not `both`. A `both` keeps the final value applied: even an identity transform creates a **permanent stacking context** that traps popovers and tooltips under neighboring cards.
- Transitions always via the easing/duration tokens (`transition: <prop> var(--ease)`); never hardcode duration or easing (they are theme decisions).
- `prefers-reduced-motion` is handled globally in `tokens.css`; individual components do not need their own guard, but must not bypass it.
- Consistent markup across pages for one block: the same component rendered as `<ul>` on one page and `<div role="list">` on another means scoped CSS applies to only one of them. Unify the markup and use element-agnostic child selectors (`> :where(div, li)`).
- One partial per component, zero inline copies: a duplicated `task-card` means only one copy receives the next fix.
- One source of nav items, looped for desktop and mobile: two hand-maintained blocks means every new item exists on only one side.
