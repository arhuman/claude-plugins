# CI Guards, UI Tests, and Regression Checklist

The lever that actually stopped UI regressions is not a framework: it is a battery of cheap CSS/HTML lints (bash + python stdlib, no JS toolchain) plus numeric ratchets.

## The audit battery

| Audit | What it prevents |
|---|---|
| `audit-css-tokens` | undefined `var()` silently falling back to the UA default |
| `audit-css-literals` | hardcoded color, so an unthemeable component |
| `audit-css` | a theme scope redeclaring structure (positioning, clearance, collapse) |
| `audit-breakpoints` | a breakpoint outside the allowlist |
| `audit-inline-styles` | growth of `style="..."` (numeric ratchet) |
| `audit-blocks-size` | uncontrolled growth of the blocks artifact |
| `audit-chip-state` | active state via class instead of ARIA |
| `audit-icon-buttons` | icon button without an accessible name |
| `audit-contrast` | contrast regression |
| `audit-css-coverage` | dead selectors |
| `lint-vocabulary` | banned term in the authenticated UI |
| `build-css-verify` | drift between section sources and the concatenated artifact |

A portable implementation of the core checks ships with this skill: `audit-ui.sh` (same directory). Subcommands `tokens`, `literals` (count-ratcheted via `baseline`), `breakpoints`, `theme-structure`, `coupling`, `states`, `bg-color` (a theme override changing `background` without redeclaring `color`), `all`; `--self-test` runs it against built-in fixtures. Wire it as the project's `make audit-ui`, or use it as the reference when the project grows its own battery. It auto-detects the CSS directory (`webroot/public/css`, `internal/static/css`, `web/assets`, `static/css`, `assets/css`) and honours `AUDIT_UI_BREAKPOINTS` for a project whose allowlist an ADR changed.

## Ratchet doctrine

- Capture the numeric baseline in `scripts/ratchets/*.txt`; any increase fails; the value never goes down "to green a build". Same for the coverage floor.
- A deliberate addition is justified by a **commented allowlist entry**, never by disabling the audit.
- Fast local loop: `make audit-ui`. Full gate: `make ci-test` / `fulltest` (audits + unit with race + live + E2E + visual + touch targets).

## UI test strategy

- **1 to 3 smoke E2E journeys** maximum; the volume goes down into ViewModel tests and golden snapshots of fragments (per template × locale).
- One test **per fragment route** verifying render order and state badges (for example: the prerequisite renders before its dependent, the Blocked badge disappears on completion).
- Playwright across **every theme the project ships** for any spacing/layout change: cascade bugs are only visible there.
- Fixed, seeded test accounts on an isolated test stack (separate compose project, ports, and volume): never hand-created users, never tests against the dev database.
- Shut down background workers before closing the DB pool in test harnesses; async inserts from a finished test flake the next one.
- Reset via `TRUNCATE ... RESTART IDENTITY CASCADE` on dynamically discovered tables (`pg_tables`), not a hardcoded list that rots at every migration.
- Pin "today" tests to the database clock, or they flake depending on the hour they run.

## Regression checklist (each line is a past incident)

Reread before any UI-touching PR.

1. **Unversioned assets + long-lived proxy cache**: fresh HTML wired to stale JS after deploy ("the button does nothing"). Use `?v=<hash>`.
2. **`204` on an HTMX swap**: the deleted element stays displayed.
3. **`hx-get="?query"`**: exponential load loop, 1500 nodes.
4. **`animation-fill-mode: both`**: tooltips trapped under neighboring cards.
5. **Active state via class**: chip visually selected while the input is unchecked.
6. **`overflow: hidden` on a modal**: submit unreachable on mobile.
7. **Drawer `position: fixed; translateX(100%)`**: global horizontal overflow. Closed state is `display: none`.
8. **Two nested surface owners**: doubled spacing, frame in frame.
9. **`<ul>` vs `<div role="list">`** for one block on two pages: CSS scoped to one markup, browser bullets on the other. Agnostic selectors (`> :where(div, li)`) + unified markup.
10. **Inline copies of one component**: only one copy receives the fix. One partial, zero copies.
11. **Separate desktop and mobile nav blocks**: every new item exists on one side only. One item source, looped.
12. **Empty-state sentinel missing**: `0m` displayed where there is no sample. Sentinel `—` + empty unit key, tested in the template.
13. **Event logged without a label snapshot**: "deleted object: id:42" in the activity feed. Snapshot labels into event details **before** deletion.
14. **Blocking notification/nudge with no lever**: dead-end CTA. Secondary channel + auto-dismiss toast, or drop the CTA; and suppress nudge rules during onboarding.

## Documentation discipline (what makes fixes reusable)

- `CHANGELOG.md` in Keep-a-Changelog format after every notable fix, with **the file touched and the root cause** in one sentence, plus a `#### Verified` line saying how it was proven (test, curl, Playwright). Without this corpus the same bugs come back.
- ADRs: one file per decision, `docs/adr/NNNN-slug.md`, **one numbering namespace** (two series always end up colliding).
- A new UI concept (term, component, state) is declared in its registry or glossary **in the same PR** as its first use.
