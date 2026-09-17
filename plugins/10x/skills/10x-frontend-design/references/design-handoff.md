# Design Handoff

How to delegate design work to any generator that does not load this skill: a
fresh Claude session, a design agent, an artifact builder, or a scratch
workspace like `.claude/claude_design/`. The rules do not travel by hope; they
travel as a brief pasted verbatim, and conformance is verified mechanically on
return. The generator is untrusted by construction: acceptance never depends on
it having read anything.

## Protocol

1. **Fill the brief.** Copy the directive below, complete the three PROJECT
   blocks (tokens, screens, components). Everything else is fixed.
2. **Hand it over verbatim**, prepended to the design request. Never summarize
   it: every paraphrase so far has dropped the constraint that mattered.
3. **Gate the result on return.** Run `audit-ui.sh all` (same directory) on the
   returned CSS, score the screen against the quality grid (>= 4/4/4 with the
   dominant action named), and check the layer order. A deliverable that fails
   the audit goes back with the audit output, not with prose feedback.

The gate is the contract. A generator that saw the brief and a generator that
ignored it are indistinguishable and equally acceptable if the audit passes.

## The directive (copy from here)

---

You are producing a design for a server-rendered web UI. These constraints are
non-negotiable; the deliverable is mechanically audited against them and
rejected on failure.

**Stack.** SSR templates + HTMX partial swaps. Hand-written CSS only: no
Tailwind, no CSS-in-JS, no Node build, no CDN assets, no web fonts fetched from
third parties. JS is progressive enhancement for UI concerns only.

**CSS architecture (CUBE + Every Layout), files in this order:**

1. `tokens.css`: custom properties only, under `:root` and theme scopes.
2. `composition.css`: layout primitives (stack, cluster, switcher, sidebar,
   grid, cover). Pure layout: no color, no typography, no borders.
3. `blocks/<name>.css`: one block per file, filename = block class. Flat
   selectors (`.block`, `.block__element`, `.block--modifier`). A block never
   styles another block's selector.
4. `utilities.css`: single-responsibility classes, no descendant selectors.

**Tokens.** Every color, spacing, radius, font, duration, and z-index goes
through a custom property. Zero literals outside `tokens.css`. Use exactly
these names (do not invent a parallel vocabulary):

- Surfaces: `--bg-base`, `--bg-surface`, `--bg-elevated`; borders
  `--border-subtle`, `--border-strong`
- Text: `--text-primary`, `--text-secondary`, `--text-muted`, `--text-inverse`
- Intent: `--accent`, `--accent-hover`, `--accent-soft`, `--on-accent`,
  `--ok`, `--warn`, `--danger` (each with `-soft`)
- Spacing: `--space-3xs` through `--space-2xl` (4px grid)
- Shape: `--radius`, `--radius-lg`, `--radius-pill`; depth `--shadow-1`,
  `--shadow-2`
- Motion: `--dur-fast`, `--dur-base`, `--dur-slow`, `--ease-standard`
- Focus and touch: `--focus-ring`, `--tap-min` (44px minimum on the smaller
  axis of every interactive element)
- Layers: `--z-dropdown`, `--z-sticky`, `--z-modal`, `--z-toast`

Name by intent, never by hue: no `--amber`, no `--green`.

**Breakpoints.** Only 640px, 880px, 1180px, written `max-width`, desktop-down.
Prefer no media query at all: switcher, grid `auto-fit`, and `clamp()` first.

**Theming.** Theme on `<html data-theme>`, server-injected. A theme scope
overrides tokens (chrome and voice: color, background, border, radius, font,
motion); it never touches structure (display, position, padding, width,
collapse). Any override changing `background` also redeclares `color`. Every
component must render correctly with no theme attribute set.

**Interaction and accessibility.**

- Every interactive element ships `:hover`, `:focus-visible`, `:active`,
  `:disabled`.
- Active/selected state via ARIA (`aria-pressed`, `aria-current`), never a CSS
  class.
- WCAG 2.1 AA contrast; document the measured ratio in a comment next to the
  token pair.
- No `animation-fill-mode: both`. No `overflow: hidden` on a modal body. One
  surface owner per region (never two nested containers each with background +
  padding + border).
- No visible string hardcoded in markup: everything through the project's i18n
  mechanism.

**Quality bar.** Before delivering, score each screen 1 to 5 on: Lisibilité
(understood in 5 seconds?), Action (one dominant action, named), Soulagement
(reduces mental load?). Deliver only at 4/4/4 or better, and state the scores
and the dominant action with the deliverable.

**PROJECT TOKENS** (values for the vocabulary above; if empty, propose values
and flag them as proposals):

```
<paste the project's tokens.css, or leave empty>
```

**PROJECT SCREENS** (route, dominant action, tension relieved, for each screen
in scope):

```
<paste the relevant rows of docs/ux.md>
```

**PROJECT COMPONENTS** (existing blocks to reuse before creating anything new):

```
<paste the component registry, or `ls blocks/`>
```

Deliverable format: the CSS files in the layer layout above, the templates,
the quality-grid scores per screen, and a list of every new token introduced
with a one-line justification each.

---

## After the handoff

- `audit-ui.sh all <css-dir>` on the returned files. Fail = bounce with output.
- Diff the token names against the canonical vocabulary; a parallel dialect
  (`--color-bg` next to `--bg-base`) is a rejection even if the audit passes,
  because it is the drift the vocabulary exists to prevent.
- New blocks land as files under `blocks/`, never appended to an existing one.
- The screen table (`docs/ux.md`) gains a row per new screen in the same
  change; `verify-ux.sh` checks it.
