# E2E Testing

## Stack

Cypress with Jasmine-style assertions. Tests live in `cypress/e2e/`. Configuration in `cypress.config.ts`.

```typescript
// cypress.config.ts
export default {
    e2e: {
        baseUrl: 'http://localhost:4200',
        chromeWebSecurity: false,
    },
    defaultCommandTimeout: 10_000,
} satisfies Cypress.ConfigOptions;
```

## Fixture-Based API Interception

Intercept API calls and replay recorded responses from a fixture file. Keys are MD5 hashes of `testName + method + url`, which allows multiple calls to the same endpoint within one test to return different responses in order.

```typescript
import { Md5 } from 'ts-md5';

let fixturesUsed: Record<string, string> = {};

beforeEach(() => {
    cy.restoreLocalStorage();

    cy.fixture('responses.json').then((data: any) => {
        cy.intercept('**', (req) => {
            if (!req.url.includes('/api/v1')) return;

            const base = String(Md5.hashStr(
                window.localStorage.getItem('testname') + req.method + req.url
            ));

            // For repeated calls to the same URL, find the first unused slot
            let key = base;
            let n = 0;
            while (fixturesUsed[key]) {
                n++;
                key = `${base}_${n}`;
            }

            if (data[key]) {
                fixturesUsed[key] = key;
                req.reply({
                    statusCode: data[key].statusCode,
                    body: data[key].body,
                    delay: 10,
                });
            }
        });
    });
});
```

## Test Structure

Set `testname` in localStorage so the fixture interceptor can scope responses per test. Call `cy.wait` and `cy.saveLocalStorage` after each test to avoid race conditions with the Cypress runner.

```typescript
describe('My Services', () => {
    afterEach(() => {
        cy.wait(1000);
        cy.saveLocalStorage();
    });

    it('shows active services', () => {
        cy.viewport(1920, 1080);

        cy.visit('/#/home/my-services', {
            onBeforeLoad(win) {
                win.localStorage.setItem('services.token', 'su');
                win.localStorage.setItem('services.lang', 'fr');
                win.localStorage.setItem('testname', Cypress.currentTest.title);
            },
        });

        cy.get('#filter-status-chip').contains('actifs');
        cy.get('#service-name-M00001').should('be.visible');
    });

    it('creates a service', () => {
        // Reset mock state on the backend if needed
        cy.exec('curl http://localhost:8080/api/v1/mocks/cleanup; exit 0');

        cy.viewport(1920, 1080);
        cy.visit('/#/home/my-services', {
            onBeforeLoad(win) {
                win.localStorage.setItem('testname', Cypress.currentTest.title);
            },
        });

        cy.get('#create-service-button').click();
        cy.get('#save-button').should('be.disabled');

        cy.get('input[name=name]').type('test', { delay: 1 });
        cy.get('input[name=label]').type('label test', { delay: 1 });

        cy.get('#save-button').should('be.enabled').click();
        cy.get('snack-bar-container').contains('Le service a été créé');
    });
});
```

## Custom Commands

Define reusable commands in `cypress/support/commands.ts` for anything repeated across tests.

```typescript
// cypress/support/commands.ts
let LOCAL_STORAGE_MEMORY: Record<string, string> = {};

Cypress.Commands.add('saveLocalStorage', () => {
    Object.keys(localStorage).forEach(key => {
        if (key.startsWith('_') || ['myapp.fixtures', 'intercepts'].includes(key)) {
            LOCAL_STORAGE_MEMORY[key] = localStorage[key];
        }
    });
});

Cypress.Commands.add('restoreLocalStorage', () => {
    Object.keys(LOCAL_STORAGE_MEMORY).forEach(key => {
        localStorage.setItem(key, LOCAL_STORAGE_MEMORY[key]);
    });
});
```

Declare types in `cypress/support/index.d.ts`:

```typescript
declare namespace Cypress {
    interface Chainable {
        saveLocalStorage(): Chainable<void>;
        restoreLocalStorage(): Chainable<void>;
    }
}
```

## Running Tests

```bash
# Interactive mode
npx cypress open

# Headless CI mode
npx cypress run

# Via npm script
npm run cypress:open
```

## Quick Reference

| Pattern | Detail |
|---------|--------|
| Fixture file | `cypress/fixtures/responses.json` |
| Fixture key | `MD5(testname + method + url)` |
| Repeated calls | Append `_1`, `_2` suffixes for ordered slots |
| Auth state | Set via `localStorage` in `onBeforeLoad` |
| Custom commands | `cypress/support/commands.ts` |
| Timeout | `defaultCommandTimeout: 10_000` |
| Security | `chromeWebSecurity: false` for cross-origin |
