# CLAUDE.md

Guidance for coding agents working in this repository. `README.md` is the user documentation;
this file is how the code is put together, the conventions to follow and the traps.

## What this is

Rephi: a Phoenix 1.8 JSON API (JWT auth with Guardian, RBAC, Phoenix Channels) plus a Yarn 4
workspace of frontends (`packages/shared-components`, `apps/example` Vite SPA,
`apps/example-astro` static Astro site). It is also a template: `installer/` builds the
`mix rephi.new` archive that clones and renames it, so everything named `rephi` / `Rephi` must
survive a whole-word rename (npm names `@rephi/*`, `rephi-*` and `mix rephi.*` tasks are kept).

## Commands

```bash
./setup.sh                   # toolchain check, .env secrets, mix setup, yarn install + builds
mix phx.server               # API on :4000; apps at /app/<name>/, Swagger at /api/swagger
mix precommit                # what CI runs: format check, warnings as errors, unused deps, tests
mix test path/to/test.exs:42 # one test
mix test --cover             # threshold 90 % (mix.exs)
mix phx.swagger.generate     # priv/static/swagger.json (build artifact, not committed)
cd installer && mix test     # the installer (also generates a project from the committed HEAD)

yarn shared:build            # ALWAYS first: apps, lint and typecheck read its compiled dist/
yarn example:dev             # :5001/app/example/
yarn example-astro:dev       # :4321
yarn build                   # every workspace, then scripts/copy-builds.js -> priv/static/apps/
yarn lint && yarn typecheck
mix rephi.gen.frontend NAME [--template example|example-astro] [--port N]
```

Toolchain: Elixir 1.20.5 / OTP 29.1.2, Node 26 (>= 22.22), Yarn 4.18 via Corepack (on Node 25+
`npm install -g corepack`). `tsc` is TypeScript 7; the `typescript` import is the TS 6 API (npm
aliases, needed by typescript-eslint). Import router APIs from `react-router`, never
`react-router-dom`.

## Backend layout

```
lib/rephi/
  accounts/accounts.ex, user.ex    Accounts: register_user (default role), change_password, reset_password, revoke_tokens
  authorization.ex                 RBAC context: load_access, can?, has_role?, assign_*/remove_*, preserving_admins
  authorization/                   Role, Permission, UserRole, UserPermission, RolePermission, RoleRole, Access
  seeds.ex                         default roles/permissions/admin as data (@roles, @permissions); run/1
  release.ex                       migrate/0, seed/0 for bin/migrate, bin/seed
  pagination.ex, health.ex, repo.ex (fetch/2, cast_id/1)
lib/rephi_web/
  router.ex                        /api (pipelines :api, :authenticated, :password_settled), /api/swagger, /app forward
  auth/                            Guardian, Pipeline, PasswordChangeGate, AuthorizationPlug, AuthorizationHelpers, ErrorHandler
  controllers/                     *_controller.ex + *_json.ex views, FallbackController, ControllerHelpers
  swagger.ex                       shared swagger definitions and swagger_path helpers
  plugs/                           FrontendAppPlug, RateLimit, ForceSSL, BodyParser
  notifications.ex, channels/      topics user:lobby / user:<id>, event new_notification
  cors.ex, rate_limiter.ex
config/runtime.exs                 every environment variable (documented in .env.example)
```

## Conventions

**Responses.** Success with a body: `{"data": ...}`; paginated lists add `meta`
(`RephiWeb.PaginationJSON.render(page, &data/1)`). Errors: `{"errors": {"detail": "..."}}` or,
for a changeset (422), `{"errors": {"field": ["..."]}}`. Never build an error body by hand:

- in an action, return `{:error, changeset}`, `{:error, :not_found}`, `{:error, :forbidden}`,
  `{:error, status_atom, "message"}` or a domain reason; every controller declares
  `action_fallback RephiWeb.FallbackController`;
- domain reasons (`:system_role`, `:last_admin`, `:escalation`, ...) map to status and message in
  `FallbackController` `@domain_errors`: add new ones there. Convention: 403 = the caller lacks
  the right for *this* change, 409 = it conflicts with the data, 422 = an invalid field;
- in a plug: `conn |> RephiWeb.FallbackController.call({:error, :too_many_requests}) |> halt()`.

**Requests.** Read write bodies with `resource_params(conn, "role")` (flat or wrapped under the
resource name; body only, never path/query). `conflict_if_taken(result, "message")` turns a
unique violation into 409.

**Ids and getters.** Use the non-raising getters: `Accounts.fetch_user/1`,
`Authorization.fetch_role/1`, `fetch_permission/1` (`{:ok, struct} | {:error, :not_found}`, any
garbage id is a 404); `get_*` return `nil`. Built on `Rephi.Repo.fetch/2` / `cast_id/1`. There
are no `get_*!` functions; do not add raising lookups to request paths.

**Authorization.** `RephiWeb.Auth.Pipeline` assigns `current_user` (a `%User{}`, never nil
behind the pipeline, associations NOT loaded) and `current_access`
(`%Rephi.Authorization.Access{}`: assigned roles, held role slugs incl. ancestors, effective
permissions). Read access, never `user.roles` / `user.permissions`.

- whole action: `plug AuthorizationPlug, {:permission, "x:y"} when action in [...]`
  (`{:any_permission, [...]}`, `{:all_permissions, [...]}`, `{:role, slug}` follow the hierarchy);
- inside an action: `can?(conn, slug)`, `has_role?/2`, `can_any?/2`, `can_all?/2`,
  `current_access(conn)` (imported by `use RephiWeb, :controller`);
- assignments always get `actor: current_access(conn)` (escalation checks, `assigned_by`),
  hierarchy links included (`assign_parent_role/3`, `remove_parent_role/3`: both roles held);
- anything that can remove the admin role from someone goes through
  `Authorization.preserving_admins/1`;
- anything that must end sessions calls `Accounts.revoke_tokens/1` (bumps `token_version`,
  broadcasts `"disconnect"` on `Accounts.socket_id/1`);
- a new authenticated route goes after `pipe_through :password_settled` in the router (a user
  whose password an admin reset gets `403` there until it sets a new one); only routes such a user
  needs to recover (`/me`, `/me/password`, logout) go before it.

**Seeds.** Data in `Rephi.Seeds` (`@roles`, `@permissions`, `@role_hierarchy`): a new default
permission is one line; seeding is idempotent, insert-only, and marks seeded rows `is_system`
(roles, permissions and the hierarchy links).
It never revokes; grants it stopped making show up in `stale_grants`.

**Migrations.** Never edit an existing migration: existing projects must be able to apply new
ones. Make them reversible.

## Adding an endpoint

1. Context function returning `{:ok, _}` / `{:error, _}` (paginated lists: `paginate_x(params)`
   with `Rephi.Pagination.paginate/2` and a stable `order_by`).
2. Route in `router.ex` under the right pipeline; controller action with `with`, a JSON view
   module rendering `%{data: ...}`.
3. Permission: add it to `@permissions` in `Rephi.Seeds` (and the roles that get it), guard the
   action with `plug AuthorizationPlug, {:permission, "things:do"} when action in [:do]`.
4. Swagger: a `swagger_path :action` block (`import RephiWeb.Swagger` gives `bearer_auth/1`,
   `id_param/3`, `page_params/1`, `body_errors/1`, `rate_limited/1`, `error_response/3`,
   `validation_response/2`), schemas in `swagger_definitions/0` wrapped in
   `RephiWeb.Swagger.definitions(%{...})`. An action routed by several verbs (`resources`
   PUT+PATCH) leaves the verb/path out and overrides the generated function with
   `operation_per_verb/1` (see `RoleController`).
5. Add the requests that produce each documented status to `cases/1` of
   `test/rephi_web/swagger_contract_test.exs` (it fails on undocumented routes, undocumented
   statuses, and on fields missing from or extra to the schema), then `mix phx.swagger.generate`.
6. Tests with `RephiWeb.ConnCase`; if the endpoint is hot, a query budget in
   `test/rephi_web/query_budget_test.exs`.

## Tests

- Helpers (`Rephi.AuthTestHelpers`, imported by `ConnCase`): `create_user/1`,
  `create_user_with_token/1`, `create_user_with_token_and(roles: [...], permissions: [...])`,
  `authenticate_conn/2`, `grant_role/2`, `grant_permission/2`, `create_role/1`,
  `create_permission/1`, `invalid_ids/0`, `error_detail(conn, status)` (asserts the envelope),
  `forge_token(user, claims)` (tokens Guardian would not issue), `put_app_env/3` (restored on
  exit; `async: false` only).
- Seeds in a test: `Rephi.Seeds.run(admin_email: nil, admin_password: nil, admin: :optional)`
  (do not depend on the shell's `ADMIN_*`).
- Query budgets: `import Rephi.QueryCounter`; `count_queries(fn -> ... end)` returns
  `{result, count}`. Login 2, `/api/me` 2, `/api/roles/:id` 4, `/api/roles/:id/parents` 4,
  `/api/users/:id/permissions` 5: if a number grows, something queries per check again.
- Channels: `connect(UserSocket, %{}, connect_info: %{auth_token: token})`.
- Rate limiting is off in test; turn it on per test with `put_app_env(RephiWeb.Plugs.RateLimit,
  ...)` + `RephiWeb.RateLimiter.reset/0`.
- `config :bcrypt_elixir, log_rounds: 1` in test; the test user password is `"password123"`.

## Frontends

- `@rephi/shared-components` is the only code that talks to the backend. Apps configure it with
  `configureRephi({apiUrl, wsUrl, debug})` in `apps/<app>/src/lib/rephi.ts`, imported first;
  nothing is baked in when the library is built (no `env.ts`, no `VITE_SERVER_API_URL`). The SPA
  reads `VITE_API_URL` / `VITE_WS_URL`, the Astro app `PUBLIC_API_URL` / `PUBLIC_WS_URL`
  (`astro:env`) and imports the library only through `~/lib/rephi`.
- Per-app `basename` and dev `port` live only in `apps/<app>/app.config.ts` (read by
  `vite.config.ts` / `astro.config.ts`; the generator rewrites them). A new dev port's origin must
  be in `:cors_origins` of `config/dev.exs`; restart `mix phx.server` after changing config.
- Phoenix serves every `priv/static/apps/<name>` at `/app/<name>/` (`FrontendAppPlug`, no router
  change). An app with a root `404.html` is multi-page (real 404s); without one, extension-less
  paths fall back to `index.html` (SPA). A SPA must not ship a root `404.html`.
- `"rephi": {"copyToPhoenix": false}` in an app's `package.json` keeps it out of
  `priv/static/apps` (the Astro app: it targets a static host).
- Authorize the UI by `permissions` (effective); `roles` in the session are only the assigned
  ones. Any 401 on the current token ends the session.
- A session user with `must_change_password` is kept on the profile page (password form) until it
  changes the password: `ProtectedRoute` in the SPA, `AppRuntime` in the Astro app.

## Traps

- `mix setup` does not build frontends; `./setup.sh` does. A fresh clone needs
  `yarn shared:build` before `typecheck`, `lint` or any app.
- `.env` is loaded in development only (`config/dotenv.exs`) and never overrides the shell;
  `mix test` reads no environment variable (`config/test.exs` is the whole configuration).
- Production refuses to boot without `DATABASE_URL`, `SECRET_KEY_BASE`, `GUARDIAN_SECRET_KEY`
  (>= 32 bytes) and `PHX_HOST`; `CORS_ORIGINS` with `*` also stops the boot.
- `FORCE_SSL` is on in prod: a local prod smoke over plain HTTP gets 301s except on
  `localhost` / `127.0.0.1` and `/api/health*`.
- `swagger.json` must exist before `mix release` (the `Dockerfile` generates it); the route
  answers 404 while it does not, and Swagger is off in prod unless `SWAGGER_ENABLED=true`.
- A changed `config/*.exs` needs a server restart (Phoenix does not reload config).
- Client routes of a SPA must not end in something extension-like (`/users/john.doe` is a 404).
- `phoenix_swagger` emits Swagger 2.0: use `"x-nullable": true`, not `nullable`.
- The installer refuses to generate if the template does not have exactly the expected
  secrets and salts (2 `secret_key_base`, 2 Guardian `secret_key`, 2 `signing_salt`): keep that
  shape when touching `config/*.exs` or `endpoint.ex`.
- Repo is public: no real hosts, IPs or personal paths in code, comments or docs.
