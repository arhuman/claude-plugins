---
name: 10x-frontend-design
description: 'UX and frontend design system for server-rendered web UIs (SSR + HTMX + hand-written CSS). Use when creating, restyling, or reviewing a page, modal, form, component, or stylesheet; when scoring a screen''s design quality ("is this page good?", "review the dashboard UI"); when defining tokens, themes, breakpoints, or UI CI guards. Provides the Lisibilité/Action/Soulagement quality grid, the CSS token contract, component and accessibility rules, HTMX UI conventions, and battle-tested regression checklists. Not for generic HTML/CSS/HTMX mechanics: use lang-html.'
---

# 10x-frontend-design

Design-quality contract for server-rendered frontends: Go SSR + HTMX fragments + hand-written CUBE CSS. Every rule here is backed either by a decision already taken in a production repo or by a bug that actually shipped.

**Precedence**: a project-local design-system skill (for example `asheeve-design-system`) wins on project specifics (class names, palettes, screen tables). This skill supplies the defaults, the quality bar, and the invariants. `lang-html` owns generic HTML/CSS/HTMX mechanics; this skill owns design quality and the UI contract.

## Reference Guide

Load the relevant reference when the task involves:

| Topic | File | Load When |
|-------|------|-----------|
| CSS contract | `references/css-contract.md` | tokens, layers, breakpoints, themability, presentation security |
| Components | `references/components.md` | buttons, chips, forms, modals, tables, states, animations |
| HTMX UI architecture | `references/htmx-ui.md` | fragments, event contract, the ten HTMX gotchas |
| Accessibility & i18n | `references/accessibility-i18n.md` | contrast, touch targets, focus, overflow, translations, glossary |
| CI guards & tests | `references/quality-guards.md` | audits, ratchets, UI test strategy, regression checklist |
| Design handoff | `references/design-handoff.md` | delegating design work to a generator that does not load this skill (another session, a design agent, an artifact builder); ships the verbatim brief and the return gate |
| Aesthetic direction | `references/aesthetics.md` | visual identity, typography, color, motion, distinctive design |

## Stack Invariants (do not rediscuss per project)

| Layer | Canonical choice | Forbidden |
|---|---|---|
| Rendering | SSR (`html/template` or `templ`) + HTMX for partial swaps | SPA shell, client routing, per-page JS bootstrap |
| CSS | Hand-written, CUBE CSS + Every Layout, zero Node build | Tailwind, CSS-in-JS, CSS bundler |
| JS | UI concerns only (theme, shortcuts, toasts, pickers); progressive enhancement | JWT in `localStorage`, `Authorization` header injection, app state in JS |
| Auth surface | JWT in HttpOnly cookie (+ `SameSite=Lax`); `Origin` check on mutating methods | tokens readable from JS |
| Assets | Embedded or static `webroot/`, versioned (`?v=<hash>`) | CDN dependencies on authenticated pages |

Why no Tailwind: a multi-model evaluation showed the CUBE-to-Tailwind migration addressed none of the root causes of real UI glitches (cascade conflicts, stacking contexts, mobile desync). The budget went to cheap CI audits and ratchets instead, which did stop the regressions.

## Quality Bar: Lisibilité / Action / Soulagement

This grid is the lens for everything else. The mechanical rules say **how** to build a screen; this section says **whether it is any good**. Score every new page or modal before shipping.

### The three qualities

**1. Lisibilité immédiate.** Every screen answers in under 5 seconds: where am I, what am I looking at, what deserves my attention?

Checklist: one explicit title, a clear visual hierarchy, few competing elements, a visible primary state, a single dominant zone. Brutal test: blur the screen slightly; can you still tell where to look? Build on the pattern: eyebrow label (where am I) + page title (what is this) + one dominant zone below. If two zones fight for attention, one of them is not the dominant one.

**2. Action évidente.** Ask of every screen: what is the one action I hope the user takes now? Not necessarily a single available action, but one **dominant** action. Aim for "here is what you can do now thanks to this data", not "here is your data". A screen that is only informational risks becoming decorative. The dominant action lives in the page-header primary CTA or the modal-footer primary submit. If you cannot name the dominant action, the screen is not done.

**3. Sentiment de soulagement.** Each screen should reduce one form of tension: too many things, too much fog, too many open decisions, too many uninterpreted metrics. After opening it, the user should think "ok, this is clearer", even if nothing is finished. Anti-pattern: the permanent analytical cockpit. Criterion: does the screen reduce mental load, or does it only prove the system is clever? If the latter, stop: that flatters the product and costs the user.

### Scoring grid (1 to 5 on each line)

| Quality | Question |
|---|---|
| Lisibilité | Do I understand the screen in 5 seconds? |
| Action | Do I know what to do now? |
| Soulagement | Does the screen reduce my mental load? |

**Pass bar: at least 4 / 4 / 4.** A good screen is balanced, not spiky.

| Unbalanced profile | Verdict |
|---|---|
| 5 lisibilité / 2 action | pretty but passive |
| 5 action / 2 soulagement | efficient but stressful |
| 5 soulagement / 2 lisibilité | poetic but vague |
| 5 intelligence / 1 soulagement | founder's trap |

### Per-project screen table (required artifact)

Each project maintains a table mapping every screen (route/template) to its expected dominant action and the tension it relieves, in the project design-system skill or CLAUDE.md. Add a row in the same PR that adds a screen. If you cannot fill both columns, the screen is not designed yet.

## Aesthetic Direction (summary)

Commit to one intentional aesthetic direction before coding, and execute it with precision: bold maximalism and refined minimalism both work; the key is intentionality, not intensity. Distinctiveness is expressed **through the token layer and theme scopes** (typography, palette, radius, motion speed), never by breaking the CSS architecture, adding ad-hoc layout CSS, or hardcoding values. Full guidance in `references/aesthetics.md`.

## Core Rules

### MUST DO

- Score every new page or modal against the quality grid (≥ 4/4/4) and name its dominant action
- Start new templates from the project scaffold files, never from a copy of an existing page
- Express every color, spacing, radius, font, duration, and z-index through a token
- Signal active/selected state through ARIA (`aria-pressed`, `aria-current`), never a CSS class
- Ship every interactive element with all four states: `:hover`, `:focus-visible`, `:active`, `:disabled`
- Serve every list bounded (server-side cap + truncation flag) or paginated
- Subscribe every list container to the mutation events its entity emits (`hx-trigger="load once, XUpdated from:body, ..."`)
- Meet WCAG 2.1 AA contrast, measured and documented next to the tokens
- Keep visible strings out of templates, JS, and `aria-label`s: everything goes through i18n
- Run the UI audit battery (`make audit-ui` or equivalent) before pushing UI changes

### MUST NOT

- Hardcode a color literal, spacing value, `font-family` string, duration, or numeric `z-index` outside `tokens.css`
- Add a breakpoint outside the canonical three defined in `references/css-contract.md`
- Use `animation-fill-mode: both` (permanent stacking context traps popovers; use `backwards`)
- Return `204` on an HTMX swap, or use `hx-get` for file downloads
- Nest two containers that each own background + padding + border (one surface owner per region)
- Use `overflow: hidden` on a modal body (clips the submit button on mobile)
- Duplicate a component inline across partials, or maintain separate desktop and mobile nav item lists
- Edit a concatenated CSS build artifact by hand (author in section files)
- Read the theme from `localStorage` in JS or set it client-side (server-injected only)
- Let a theme scope redeclare structure (positioning, clearance, responsive collapse): themes own chrome and voice only

## Working Order on a UI Feature

1. Read the project CLAUDE.md, the relevant ADRs, and the vocabulary glossary.
2. Slice vertically: data → service → fragment → UI → ordering/display. Ship "data layer PR" then "end-to-end PR".
3. Start from the scaffold, reuse an existing partial; create a new CSS block only as a last resort, and in a section file, never in the build artifact.
4. Run the UI audits, then Playwright across **every theme the project ships** for any spacing/layout change (cascade bugs are only visible there).
5. Write the regression test at the level where the bug was visible (route/fragment test for a rendering problem).
6. CHANGELOG entry with root cause + how it was verified. Conventional commit.

Done when: the screen scores at least 4/4/4 on the quality grid with its dominant action named, the UI audit battery passes, the per-project screen table has a row for every screen the change added, and the CHANGELOG entry exists.
