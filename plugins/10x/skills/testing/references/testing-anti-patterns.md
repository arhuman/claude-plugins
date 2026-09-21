# Testing Anti-Patterns

Test actual behavior, not mock behavior. Inspect these signals and apply the corresponding correction:

## The Five Anti-Patterns

| Signal | Required correction |
|---|---|
| Only `expect(mock).toHaveBeenCalled()`, no output assertion | Assert genuine component output; reconsider value if only calls are observable. |
| Production `_reset`, `_setForTest`, `ForTesting` methods solely for tests | Move setup/cleanup to test utilities; use fresh instances per test. |
| Every dependency mocked, or 10+ mocks/test | Run real implementations first to understand side effects; mock external services, not internal logic. |
| Partial responses, e.g. only `{ success: true }` | Mirror complete real API structure, including downstream fields; use factories with sensible defaults. |
| Tests deferred until after shipping | Testing is implementation; ship features and tests together, follow [test-first contracts](tdd-iron-laws.md). No feature done without tests. |

Adapted from [obra/superpowers](https://github.com/obra/superpowers), Jesse Vincent (@obra), MIT License.
