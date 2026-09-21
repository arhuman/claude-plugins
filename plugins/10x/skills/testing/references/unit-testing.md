# Unit Testing

## Go: Table-Driven Tests

For Go, consult the canonical [lang-go testing guide](../../lang-go/references/testing.md) for table tests, mocking, benchmarks, fuzzing and coverage. Use `t.Run` and testify `assert` (nonfatal) or `require` (fatal), interface test doubles, and test setup accepting `*testing.T`. Race/coverage execution requirements live in [testing constraints](../SKILL.md#constraints).

## TypeScript: Angular Unit Tests (Jasmine + TestBed)

Use Jasmine `describe`/`it`, `beforeEach` TestBed setup, and `jasmine.createSpyObj(name, methodNames)` for injected services, provided as `{ provide: ServiceClass, useValue: spy }`. Create the component fixture, run change detection, and assert rendered behavior, including invalid-form disabled actions. Import required forms modules and supply observable service responses when expected.

Run `ng test` using the project's runner. Karma is deprecated; new projects use Web Test Runner or Jest per Angular configuration.
