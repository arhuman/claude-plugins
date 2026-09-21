# TypeScript Project Structure

## Angular Application (standalone-first)

Organize `src/app/` by feature:
- `core/`: singleton services, auth guards/interceptors, HTTP; no module file.
- `shared/`: reusable standalone components, pipes, directives.
- `features/<feature>/`: component folders with `.ts`, `.html`, `.spec.ts`; feature service/model and `<feature>.routes.ts` exporting a `Routes` constant.
- `app.routes.ts`: lazy feature composition via `loadChildren: () => import(...).then(m => m.USERS_ROUTES)`; `app.config.ts`: providers; `app.component.ts`: root.
- Under `src/`: `assets/`, `styles/`, `environments/environment.ts` and `environment.prod.ts`.

### Angular Conventions

- New components are standalone and import exactly their template dependencies; no shared-module barrel. No new NgModules; migrate legacy modules opportunistically when touched.
- One component per file; align selector/file naming (`UserListComponent`: `user-list.component.ts`).
- Put `provideRouter`, `provideHttpClient(withInterceptors(...))` in `app.config.ts`; use `providedIn: 'root'` unless feature-scoped.
- Use functional `CanActivateFn` guards and `HttpInterceptorFn` interceptors.
- Models are logic-free interfaces. Keep components/templates thin; business logic belongs in services. Containers handle data/routing; presentation takes signal inputs and emits outputs.
- Use `OnPush` or zoneless bootstrap.

## Node.js / Express API

Under `src/`, use `controllers/` for thin handlers delegating to `services/` (business logic), `repositories/` for per-entity data access, `models/` for types, `middleware/` for auth/logging/validation, `config/` for loading/validation, `utils/` for pure functions, `index.ts` for entry. Tests: `tests/unit/services/`, `tests/integration/routes/`, `tests/fixtures/`.

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

Gate: compiler settings include strict mode, indexed-access and exact-optional checks; changed files follow their layer's responsibilities.
