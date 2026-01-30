# Unit Testing

## Go: Table-Driven Tests

The standard pattern for all non-trivial Go tests. Use `t.Run` for subtests.

```go
func TestConfigValidation(t *testing.T) {
    tests := []struct {
        name        string
        input       Config
        expectError bool
    }{
        {
            name:        "valid config",
            input:       Config{Directory: ".", MappingFile: "test.csv"},
            expectError: false,
        },
        {
            name:        "missing directory",
            input:       Config{MappingFile: "test.csv"},
            expectError: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := tt.input.Validate()
            if tt.expectError {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

Always use `github.com/stretchr/testify/assert` (non-fatal) or `require` (fatal on failure).

## TypeScript: Angular Unit Tests (Jasmine + TestBed)

```typescript
import { TestBed, ComponentFixture } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { of } from 'rxjs';

describe('ManagementComponent', () => {
    let fixture: ComponentFixture<ManagementComponent>;
    let component: ManagementComponent;

    beforeEach(() => {
        const userService = jasmine.createSpyObj('UserService', ['getUsers', 'deleteUser']);
        userService.getUsers.and.returnValue(of([{ id: 1, name: 'Alice' }]));

        TestBed.configureTestingModule({
            declarations: [ManagementComponent],
            imports: [ReactiveFormsModule],
            providers: [
                { provide: ComponentFixtureAutoDetect, useValue: true },
                { provide: UserService, useValue: userService },
            ],
        });

        fixture = TestBed.createComponent(ManagementComponent);
        component = fixture.componentInstance;
    });

    it('renders the user list', () => {
        fixture.detectChanges();
        const rows = fixture.debugElement.queryAll(By.css('.user-row'));
        expect(rows.length).toBe(1);
    });

    it('disables save button when form is invalid', () => {
        fixture.detectChanges();
        const btn = fixture.debugElement.query(By.css('#save-button'));
        expect(btn.nativeElement.disabled).toBeTrue();
    });
});
```

Use `jasmine.createSpyObj(name, methodNames)` to mock services injected via DI. Provide them with `{ provide: ServiceClass, useValue: spy }`.

## Quick Reference

| Pattern | Go | TypeScript |
|---------|----|------------|
| Test runner | `go test ./...` | `ng test` (Karma) |
| Assertions | `assert.Equal`, `require.NoError` | `expect(...).toBe`, `expect(...).toBeTruthy` |
| Mocking | test doubles via interfaces | `jasmine.createSpyObj()` |
| Setup | `SetupData(t *testing.T)` | `beforeEach(() => TestBed.configureTestingModule(...))` |
| Table tests | `[]struct{}` + `t.Run` | `describe`/`it` nesting |
| Race detection | `go test -race ./...` | n/a |
