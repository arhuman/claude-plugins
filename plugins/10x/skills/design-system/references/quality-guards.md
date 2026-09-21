# CI Guards, UI Tests, and Regression Checklist

Use cheap CSS/HTML audits (bash + Python stdlib, no JS toolchain) with numeric ratchets.

## The audit battery

| Audit | Gate |
|-------|------|
| `audit-css-tokens` | Defined var() tokens |
| `audit-css-literals` | No new hardcoded colors |
| `audit-css` | No theme structure redeclarations |
| `audit-breakpoints` | Allowlisted queries |
| `audit-inline-styles` | Style-attribute ratchet |
| `audit-blocks-size` | Artifact growth |
| `audit-chip-state` | ARIA selection |
| `audit-icon-buttons` | Accessible names |
| `audit-contrast` | Contrast floor |
| `audit-css-coverage` | Dead selectors |
| `lint-vocabulary` | Auth UI vocabulary |
| `build-css-verify` | Section/artifact parity |

Wire adjacent `audit-ui.sh` as `make audit-ui` or use it as reference. Subcommands: `tokens`, `literals` (count ratchet via `baseline`), `breakpoints`, `theme-structure`, `coupling`, `states`, `bg-color`, `all`; `--self-test` exercises fixtures. Auto-detects `webroot/public/css`, `internal/static/css`, `web/assets`, `static/css`, `assets/css`; `AUDIT_UI_BREAKPOINTS` supports ADR-approved allowlists.

## Ratchet doctrine

Baselines in `scripts/ratchets/*.txt`; fail increases, never loosen a baseline or coverage floor merely to pass. Deliberate exceptions need commented allowlist entries, not disabled audits. Local: `make audit-ui`; full: `make ci-test`/`fulltest` (audits, race units, live, E2E, visual, touch).

## UI test strategy

- 1-3 smoke E2E journeys maximum; favor ViewModel tests and per-template × locale golden fragments.
- Test each fragment route's render order/state badges. Layout/spacing changes: Playwright every shipped theme.
- Fixed seeded accounts, isolated Compose project/ports/volume; never dev DB or hand-created users.
- Stop workers before DB pool close. Reset dynamically discovered `pg_tables` with `TRUNCATE ... RESTART IDENTITY CASCADE`; no hardcoded table list. Pin “today” to DB clock.

## Regression checklist (each line is a past incident)

Before UI PRs, read the owning references:

- `htmx-ui.md`: versioned assets, 200 swaps, guarded fragment URLs, pre-delete label snapshots and mutation coupling.
- `components.md`: backwards animation fill, native/ARIA state, scrollable modals, single surface owner, consistent markup/partials/nav source, empty-sample sentinel and empty unit key.
- `accessibility-i18n.md`: closed drawers removed from layout, overflow and locale coverage.
- Notifications/nudges must offer a real lever; otherwise use secondary channel + auto-dismiss toast or drop CTA. Suppress nudges during onboarding.

## Documentation discipline (what makes fixes reusable)

- Notable fixes: Keep-a-Changelog entry naming file + root cause in one sentence, with `#### Verified` and actual proof (test/curl/Playwright).
- ADRs: `docs/adr/NNNN-slug.md`, one numbering namespace.
- New terms/components/states enter registry/glossary in the same PR as first use.
