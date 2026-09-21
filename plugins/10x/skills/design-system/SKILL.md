---
name: design-system
description: 'Design-quality contract for SSR + HTMX + hand-written CSS. Use to create, restyle, review or score pages, modals, forms, components, tokens, themes, breakpoints and UI guards. Owns Readability/Action/Relief scoring, CSS/component/a11y/i18n rules. For generic HTML/CSS/HTMX mechanics use `lang-html`.'
---
# design-system

Project-local design-system skills override project specifics (classes, palettes, screen tables); these defaults and invariants complement `lang-html` mechanics.

## Reference Guide

Load when the task involves:

| Topic | Reference |
|-------|-----------|
| Tokens, layers, breakpoints, themes, CSP | `references/css-contract.md` |
| Buttons, forms, modals, tables, states, motion | `references/components.md` |
| Fragments, mutation events, HTMX pitfalls | `references/htmx-ui.md` |
| Contrast, focus, overflow, translations/glossary | `references/accessibility-i18n.md` |
| Audits, ratchets, tests, regression review | `references/quality-guards.md` |
| Generator without this skill | `references/design-handoff.md` (verbatim brief + return gate) |
| Visual identity | `references/aesthetics.md` |

## Stack Invariants (do not rediscuss per project)

| Layer | Required | Forbidden |
|-------|----------|-----------|
| Rendering | SSR (`html/template`/`templ`) + HTMX | SPA, client routing, per-page JS bootstrap |
| CSS | Hand-written CUBE + Every Layout, zero Node build | Tailwind, CSS-in-JS, bundler |
| JS | UI-only progressive enhancement | app state, localStorage JWT, Authorization injection |
| Auth | JWT HttpOnly + SameSite=Lax cookie; Origin checks on mutations | JS-readable tokens |
| Assets | Embedded/static `webroot/`, `?v=<hash>` | authenticated-page CDN dependencies |

## Quality Bar: Readability / Action / Relief

Score every new page/modal before shipping.

### The three qualities

- **Immediate readability:** under 5 seconds to identify location, content and priority. Explicit title, eyebrow context, visible primary state, clear hierarchy, one dominant zone; verify focus remains clear when blurred.
- **Obvious action:** name one dominant action in the page-header CTA or modal-footer submit. Data must make the next action clear.
- **Relief:** reduce overload, ambiguity, open decisions or uninterpreted metrics. Reject permanent analytical cockpits that add mental load.

### Scoring grid (1 to 5 on each line)

| Quality | Question |
|---------|----------|
| Readability | Understood in 5 seconds? |
| Action | Obvious next action? |
| Relief | Less mental load? |

Each score must be **≥ 4 (4/4/4)**; a high score cannot offset a low one.

### Per-project screen table (required artifact)

Maintain route/template, dominant action and tension relieved in the project design-system skill or CLAUDE.md. Add each new screen's row in the same PR; both columns are required.

## Aesthetic Direction (summary)

Commit to one direction before coding. Express identity through tokens/theme chrome, preserving layout architecture; load `references/aesthetics.md`.

## Core Rules

### MUST DO

- Start templates from project scaffolds, reuse partials; all colors/spacing/radii/fonts/durations/z-indexes use tokens.
- Native/ARIA selected state; all interactive elements have hover, focus-visible, active, disabled states.
- Paginate or server-cap lists with truncation flags; subscribe lists to all entity mutations.
- Measured WCAG 2.1 AA contrast beside tokens; all visible strings, including JS/ARIA, use i18n.
- Run UI audits before pushing.

### MUST NOT

- Hardcode design values outside `tokens.css`, add noncanonical breakpoints, or hand-edit concatenated CSS.
- Use `animation-fill-mode: both`, modal-body `overflow: hidden`, or nested background/padding/border owners.
- Return 204 for swaps, use `hx-get` for downloads, duplicate component partials or desktop/mobile nav sources.
- Read theme from localStorage or set it client-side; theme scopes must not redefine structure.

## Working Order on a UI Feature

1. Read project CLAUDE.md, relevant ADRs and glossary.
2. Slice data -> service -> fragment -> UI -> ordering/display; data-layer PR then end-to-end PR.
3. Scaffold and reuse first; new blocks last, authored in section files.
4. Run audits and, for spacing/layout, Playwright across every shipped theme.
5. Regression test where the bug was visible (route/fragment for rendering).
6. CHANGELOG: root cause + verification; Conventional Commit.

Done: ≥ 4/4/4 with dominant action named, audits pass, screen-table rows and CHANGELOG entry exist.
