# TypeScript Project Structure

## Angular Application (standalone-first)

Standalone components are the default since Angular 17; new code does not use NgModules. Organize by feature, with routes as the composition mechanism:

```
src/
├── app/
│   ├── core/                    # Singleton services, guards, interceptors (no module file)
│   │   ├── auth/
│   │   │   ├── auth.service.ts
│   │   │   ├── auth.guard.ts    # Functional guard: export const authGuard: CanActivateFn
│   │   │   └── auth.interceptor.ts  # Functional interceptor: HttpInterceptorFn
│   │   └── http/
│   ├── shared/                  # Reusable standalone components, pipes, directives
│   │   ├── components/
│   │   └── pipes/
│   ├── features/                # Feature areas, lazy-loaded via routes
│   │   └── users/
│   │       ├── user-list/
│   │       │   ├── user-list.component.ts   # standalone, imports what it uses
│   │       │   ├── user-list.component.html
│   │       │   └── user-list.component.spec.ts
│   │       ├── user-detail/
│   │       ├── user.service.ts
│   │       ├── user.model.ts
│   │       └── users.routes.ts  # export const USERS_ROUTES: Routes
│   ├── app.routes.ts            # lazy-load features: loadChildren: () => import(...).then(m => m.USERS_ROUTES)
│   ├── app.config.ts            # provideRouter, provideHttpClient, ...
│   └── app.component.ts
├── assets/
├── environments/
│   ├── environment.ts           # Development
│   └── environment.prod.ts      # Production
└── styles/
```

### Angular Conventions

- One component per file. File name matches selector: `UserListComponent` → `user-list.component.ts`
- Standalone components import exactly what their template uses; no barrel "shared module"
- Providers go in `app.config.ts` (`provideRouter`, `provideHttpClient(withInterceptors(...))`); services are `@Injectable({ providedIn: 'root' })` unless feature-scoped
- Guards and interceptors are functions (`CanActivateFn`, `HttpInterceptorFn`), not classes
- Models are plain interfaces, not classes (no logic in models)
- Smart (container) components handle data and routing; dumb (presentational) components take signal inputs and emit outputs
- Use `OnPush` change detection (or a zoneless bootstrap): signals make this the natural default
- NgModules survive only in legacy code; do not add new ones, and migrate opportunistically when touching old features

## Node.js / Express API

```
src/
├── controllers/         # Route handlers: thin, delegate to services
├── services/            # Business logic
├── repositories/        # Data access: one per entity
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

Enable `noUncheckedIndexedAccess` and `exactOptionalPropertyTypes`: they catch real bugs the base `strict` flag misses.
