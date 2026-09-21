# E2E Testing

Prefer Playwright for new suites. Apply the following only to existing Cypress suites, adapting reference-project fixture/storage conventions.

## Stack

Cypress tests: `cypress/e2e/`; config: `cypress.config.ts`. Reference settings: localhost frontend port 4200, `defaultCommandTimeout: 10_000`; `chromeWebSecurity: false` is the reference cross-origin setting, not a universal default.

## Fixture-Based API Interception

Replay `cypress/fixtures/responses.json` for the relevant API prefix. Key by `MD5(testname + method + url)`; repeated calls consume first unused slots with `_1`, `_2` suffixes in order. Reply with recorded status/body (reference delay: 10ms); keep consumption state isolated per test.

## Test Structure

Set localStorage `testname` from current test title, plus needed auth/language state, in visit `onBeforeLoad`. Restore saved storage before each test; after each, wait for completion then save it to avoid runner races (legacy example: `cy.wait(1000)`, prefer deterministic waits). Reset backend mock state when needed. Assert visible results and form disabled/enabled transitions, not merely clicks. Reference desktop viewport: 1920x1080.

## Custom Commands

Put repeated commands in `cypress/support/commands.ts`; declare `Chainable<void>` save/restore signatures in `cypress/support/index.d.ts`. Preserve only intended storage keys (reference allowlist: `_` prefix, `myapp.fixtures`, `intercepts`), without introducing test order dependence.

## Running Tests

Interactive: `npx cypress open` (or existing `npm run cypress:open`); CI: `npx cypress run`.
