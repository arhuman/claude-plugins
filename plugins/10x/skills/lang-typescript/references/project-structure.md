# TypeScript Project Structure

## Angular Application

```
src/
├── app/
│   ├── core/                    # Singleton services, guards, interceptors
│   │   ├── auth/
│   │   ├── http/
│   │   └── core.module.ts       # Import once in AppModule
│   ├── shared/                  # Reusable components, pipes, directives
│   │   ├── components/
│   │   ├── pipes/
│   │   └── shared.module.ts
│   ├── features/                # Feature modules (lazy-loaded)
│   │   └── users/
│   │       ├── components/
│   │       │   ├── user-list/
│   │       │   │   ├── user-list.component.ts
│   │       │   │   ├── user-list.component.html
│   │       │   │   └── user-list.component.spec.ts
│   │       │   └── user-detail/
│   │       ├── services/
│   │       │   └── user.service.ts
│   │       ├── models/
│   │       │   └── user.model.ts
│   │       └── users.module.ts
│   ├── app-routing.module.ts
│   ├── app.component.ts
│   └── app.module.ts
├── assets/
├── environments/
│   ├── environment.ts           # Development
│   └── environment.prod.ts      # Production
└── styles/
```

### Angular Conventions

- One component per file. File name matches selector: `UserListComponent` → `user-list.component.ts`
- Services are `@Injectable({ providedIn: 'root' })` unless they need feature-scoped state
- Models are plain interfaces, not classes (no logic in models)
- Smart (container) components handle data and routing; dumb (presentational) components take inputs and emit outputs
- Use `OnPush` change detection for presentational components

## Node.js / Express API

```
src/
├── controllers/         # Route handlers — thin, delegate to services
├── services/            # Business logic
├── repositories/        # Data access — one per entity
├── models/              # TypeScript interfaces and types
├── middleware/          # Express middleware (auth, logging, validation)
├── config/              # Configuration loading and validation
├── utils/               # Pure utility functions
└── index.ts             # Entry point

tests/
├── unit/
│   └── services/
├── integration/
│   └── routes/
└── fixtures/
```

### tsconfig.json baseline

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  }
}
```

Enable `noUncheckedIndexedAccess` and `exactOptionalPropertyTypes` — they catch real bugs the base `strict` flag misses.
