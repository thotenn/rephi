# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Browser tests of `apps/example`** - a Playwright suite (`apps/example/e2e/`, `yarn example:e2e`)
  covering sign-in, registration, logout, password change, the dashboard quick actions, the
  administration screens on throwaway data and a "no dead controls" check that clicks every link
  and button of every page. Optional CI workflow `e2e-example.yml`

### Fixed
- **Dashboard quick actions (`apps/example`)** - "Create New Item" and "View Reports" did nothing.
  They are now links, each shown only with the permissions it needs: "New role" (opens the
  create-role form), "Send notification" (the broadcast form, message field focused), "Manage
  users" and "My profile"
- **`apps/example`** - "Go Back" on the access-denied page did nothing (or left the app) on a page
  opened directly; it now goes home. The error page (including unknown paths) links back home
- **`apps/example`** - ESLint resolves its TypeScript config and `~/` imports when run from the
  repository root, as an editor does

## [0.2.0] - 2026-11-16

A toolchain upgrade and a full audit of the boilerplate: security, RBAC, the API contract, the
generators and the frontends. Entries marked **Breaking** change something a client, a deployer or
an existing project can notice; [Upgrading from 0.1.0](#upgrading-from-010) says what to do.

### Added
- **Astro example** - `apps/example-astro`, the example app rebuilt with Astro 7 as a static,
  multi-page site (React islands, Tailwind CSS 4) with every integration of the SPA, ready for
  Cloudflare Pages (`wrangler.jsonc`, `_headers`, a real `404.html`). Scripts
  `yarn example-astro:dev` (port 4321) and `yarn example-astro:build`
- **Health checks** - `GET /api/health` (liveness, no database) and `GET /api/health/ready`
  (readiness: 503 when the database does not answer within 1 second), unauthenticated and not
  logged
- **`GET /`** answers `{"data": {"name": ..., "health": "/api/health"}}`
- **Logout** - `POST /api/users/logout` (204) revokes every token of the user on every device and
  closes its WebSockets
- **Change my password** - `PUT /api/me/password` with `current_password` and `password`: revokes
  the previous tokens and returns a new session in the shape of login
- **Revocable tokens** - each user has a `token_version`, carried in the token as the `ver`
  claim. A password change, a logout or deleting the user invalidates every token issued before
  and closes the user's sockets
- **Rate limiting** of login, `PUT /api/me/password` (10 per minute) and registration (5 per
  minute) per client IP: `429` with a `retry-after` header (`RephiWeb.Plugs.RateLimit`, in
  memory, configurable, aware of trusted reverse proxies)
- **Pagination** of `GET /api/users`, `/api/roles` and `/api/permissions`: `page`, `page_size`
  (default 50, at most 100) and `meta: {page, page_size, total, total_pages}`
- **System records** - `is_system` on roles and permissions: the seeded ones cannot be deleted
  (409) nor change slug (422)
- **Role detail** separates `permissions` (assigned to the role) from `inherited_permissions`
  (each with `inherited_from`); `GET /api/roles/:id/permissions` flags each entry `inherited`
- Permission `notifications:broadcast` (18 seeded permissions); the broadcast event carries its
  sender (`from: {id, email}`, `null` for system notifications)
- Private channel `user:<id>`, joinable only by that user, and
  `RephiWeb.Notifications.notify_user/3` to send to it
- The socket accepts the token as Phoenix's `authToken` (in the `Sec-WebSocket-Protocol` header,
  never in the URL); the `token` param still works
- Default role on registration (`config :rephi, Rephi.Accounts, default_role: "user"`; `nil`
  turns it off) and a configurable administrator role
  (`config :rephi, Rephi.Authorization, admin_role: "admin"`)
- `Rephi.Authorization.load_access/1`: roles and effective permissions in one query, loaded once
  per request into `conn.assigns.current_access` and reused by every check; `has_direct_role?/2`,
  `can_grant_role?/2`, `can_grant_permission?/2`, `can_manage_user?/2`, `preserving_admins/1`
- Non-raising getters: `Rephi.Repo.fetch/2`, `Accounts.fetch_user/1`,
  `Authorization.fetch_role/1`, `fetch_permission/1`
- Runtime configuration from the environment: `CORS_ORIGINS`, `CHECK_ORIGIN`, `FORCE_SSL`,
  `SWAGGER_ENABLED`, `TOKEN_TTL_SECONDS`, `RATE_LIMIT_ENABLED`, `RATE_LIMIT_LOGIN_MAX`,
  `RATE_LIMIT_REGISTER_MAX`, `RATE_LIMIT_WINDOW_SECONDS`, `RATE_LIMIT_TRUSTED_PROXIES`,
  `ADMIN_EMAIL` / `ADMIN_PASSWORD` (see `.env.example`)
- **Releases** - `Dockerfile` (frontends, `swagger.json` and the release in one image),
  `Rephi.Release` with `bin/migrate`, `bin/seed` and `bin/server`
- **CI** - `.github/workflows/ci.yml`: `mix precommit` against PostgreSQL, the installer's tests,
  and `yarn install --immutable`, `shared:build`, `typecheck`, `lint`, `build`
- `mix precommit` (format check, warnings as errors, unused dependencies, tests) and a coverage
  threshold of 90 % (`mix test --cover`)
- `mix rephi.gen.frontend NAME --template example|example-astro --port N`
- `@rephi/shared-components`: `configureRephi({apiUrl, wsUrl, debug})` (nothing is inlined when
  the library is built), `ApiError` and `describeError` / `getErrorMessage` / `getFieldErrors`,
  `login` / `register` / `fetchMe` / `logout` / `changePassword`, `onSessionEnd`, pagination
  helpers (`fetchPage`, `fetchAllPages`, `describePage`, `hasNextPage`), `useChannel` /
  `useChannelEvent` / `usePhoenixSocket`, `LOBBY_TOPIC` / `userTopic` / `NOTIFICATION_EVENT`
- Per-app settings in `apps/<app>/app.config.ts` (`basename`, dev `port`)
- `scripts/copy-builds.js`: an app opts out of `priv/static/apps` with
  `"rephi": {"copyToPhoenix": false}`; `--app NAME` copies one app
- `test/rephi_web/swagger_contract_test.exs`: every route is documented and every documented
  response is checked against a real request; query-budget tests (`Rephi.QueryCounter`)

### Changed
- Backend toolchain: Elixir 1.20.5 / Erlang/OTP 29.1.2 (`.tool-versions`; Elixir `~> 1.19`
  required) and every Hex dependency at its latest release (Phoenix 1.8.16, Ecto SQL 3.14,
  Plug 1.20, Bandit 1.14, Guardian 2.5, Phoenix Swagger 0.8.5...). Logger configuration under
  `:default_formatter`; `Phoenix.CodeReloader` registered as a Mix listener
- Frontend toolchain: Node.js 26 LTS (22.22 minimum), Yarn 4.18 through Corepack, Vite 8,
  TypeScript 7 (next to the TypeScript 6 API that lint tooling needs), ESLint 10 flat config in
  every workspace, React 19.3, React Router 8 (imports from `react-router`), Zod 4,
  Tailwind CSS 4.3, `phoenix` 1.8
- **Breaking** - every successful response with a body is `{"data": ...}` and every error is
  `{"errors": {"detail": "..."}}`, or `{"errors": {"<field>": ["..."]}}` for a 422. The top-level
  `error`, `message`, `user`, `token` and `notification` keys are gone
- **Breaking** - register and login answer `{"data": {"user", "token"}}`, `GET /api/me`
  `{"data": {"user"}}`; the user carries `roles` (assigned) and `permissions` (effective) in all
  three
- **Breaking** - tokens last 24 hours (they lasted 28 days; `TOKEN_TTL_SECONDS`). Only access
  tokens of this issuer, with `exp`, an existing `sub` and the current `ver` are accepted:
  anything else is a 401, never a 500
- **Breaking** - `POST /api/notifications/broadcast` requires `notifications:broadcast` (only
  `admin` has it), trims `message` (1 to 500 characters) and answers the notification in `data`
- **Breaking** - `/api/users*` is authorized by `users:view` / `users:edit` / `users:delete`
  instead of the `admin` role. The seeded `user` role holds no permission (`users:view` moved to
  `manager`). Editing or deleting a user who holds roles the caller does not hold is a 403 unless
  the caller is an admin
- **Breaking** - `PUT /api/users/:id` only changes the email; a `password` in the body is a 422
  (users change their own with `PUT /api/me/password`)
- **Breaking** - registration assigns the default role `user`
- **Breaking** - granting or revoking a role requires holding it, and a permission holding it,
  unless the caller is an admin (403). Duplicate assignments are a 409; assignments answer 201 with
  the created record; `assigned_by` is always the caller
- **Breaking** - 409 for deleting a system role or permission, removing the admin role from its
  last holder, deleting your own account and revoking from a role a permission it only inherits
- **Breaking** - an invalid `:id` (not a number, out of range, unknown) is a 404, never a 400 or
  a 500; an unknown route is a 404 JSON (the HTML catch-all is gone)
- **Breaking** - write endpoints accept their attributes flat or wrapped under the resource name
  (`{"role": {...}}`); an incomplete body is a 422 instead of a 400
- **Breaking** - emails are stored trimmed and lowercased and unique regardless of case;
  passwords need 8 characters (72 bytes at most)
- **Breaking** - frontends are served by one generic mount at `/app/<name>` for every directory
  of `priv/static/apps`: real 404s for missing assets, a SPA fallback to `index.html` for
  extension-less paths, or the app's own `404.html` (multi-page sites), `301` to the trailing
  slash, `ETag` / `Range`, immutable caching of `assets/` and `_astro/`, only `GET` / `HEAD`
- **Breaking** - CORS comes from `CORS_ORIGINS` (exact origins or `https://*.example.com`
  wildcards; `*` refuses to boot). In production the WebSocket origin check accepts `PHX_HOST`
  plus those origins (`CHECK_ORIGIN` overrides)
- **Breaking** - production requires `DATABASE_URL`, `SECRET_KEY_BASE`, `GUARDIAN_SECRET_KEY`
  (at least 32 bytes) and `PHX_HOST`, and redirects HTTP to HTTPS with HSTS (`FORCE_SSL=false`
  turns it off; the scheme comes from `X-Forwarded-Proto`)
- **Breaking** - seeding requires `ADMIN_EMAIL` / `ADMIN_PASSWORD` outside development; the
  well-known `admin@admin.com` account is only created in development. Seeds are idempotent and
  transactional, mark the seeded records as system records, and report (never revoke) grants the
  seed no longer makes
- **Breaking** - Swagger UI and `swagger.json` are off in production unless
  `SWAGGER_ENABLED=true`; `swagger.json` has a route of its own (404 with a hint until generated)
  and no hard-coded host
- **Breaking** - `mix setup` prepares Phoenix only (deps, database, seeds, `swagger.json`);
  `./setup.sh` checks the toolchain, writes a development `.env` with its own secrets and builds
  the frontends
- **Breaking** - the `.env` file is loaded in development only and never overrides variables
  already set
- **Breaking** - `@rephi/shared-components` speaks the new contract: every failed request
  rejects with an `ApiError`; any 401 on the current token ends the session; logout calls the
  server; the socket authenticates with `authToken` and ends the session when the server closes
  it for good; `PaginatedResponse` has `meta`; `User` is the session user
  (`{id, email, roles, permissions}`); `RephiNotification` has `from`
- **Breaking** - the installer is installed with
  `mix archive.install github thotenn/rephi --sparse installer` (0.2.0, not on Hex) and gives
  every project its own development/test secrets and signing salts, renames everything (seeds,
  `.env.example`, tests, file names), formats the project and commits it on `main`
- `mix rephi.gen.frontend` validates everything before writing (and writes atomically), accepts
  names with `-`, picks a free port and adds its origin to the development CORS list, edits
  `apps/NAME/app.config.ts` and no longer touches the router or `packages/`
- `yarn build` replaces each `priv/static/apps/<app>` (no stale assets) and fails when an app has
  no build
- Response JSON headers: `x-content-type-options`, a `default-src 'none'` CSP, `referrer-policy`;
  request bodies are limited to 1 MB, and a malformed or oversized body keeps its CORS headers
- Permission checks cost no query inside a request (login 29 → 2 queries, `/api/me` 15 → 2,
  `/api/roles/:id` 28 → 4); effective permissions come from one recursive query that tolerates
  cycles
- Timestamps of roles, permissions and assignments are UTC (`Z`), like users'
- `Rephi.Accounts.UserRole` / `UserPermission` are now `Rephi.Authorization.UserRole` /
  `UserPermission`; `Authorization.has_role?/2` and `{:role, slug}` follow the role hierarchy
- `swagger.json` describes the real API: every route, integer ids, the envelopes, every status
  code, no phantom fields

### Removed
- **Breaking** - the `"shout"` channel event: clients cannot broadcast over the socket (the only
  client event is `ping`)
- **Breaking** - CSRF token injection into the frontends' HTML and its client code
  (`csrf.ts`, `setCsrfHeader`, `__CSRF_TOKEN__`): the API authenticates with Bearer tokens and
  never checked it
- **Breaking** - `AppController`, the `/dashboard*` routes, the `?app=` parameter, the static
  mounts of `/dashboard`, `/admin`, `/ecommerce` and `/landing`, the per-app `forward` routes and
  the HTML layouts
- **Breaking** - `mix frontends.build` / `mix frontends.clean`, `lib/mix/tasks/rephi.new.ex` and
  the Hex package metadata of the root project
- **Breaking** - `Authorization.can_by?/1`, `get_role!/1`, `get_permission!/1`,
  `Accounts.get_user!/1`, `Accounts.list_users/0` (use `paginate_users/1`) and the controller
  helpers `authorize/2`, `current_user/1`, `current_user_roles/1`, `current_user_permissions/1`
  (use `current_access(conn)`)
- **Breaking** - `@rephi/shared-components`: `env` / `Env` and every build-time variable
  (`VITE_SERVER_API_URL`, `VITE_<APP>_PORT`), `PhoenixProvider` / `usePhoenix`, the old
  `usePermissions` signature, the second `auth_token` storage key
- Environment variables nothing read: `FRONTEND_URL`, `MAIL_ADAPTER`, `CODE_RELOADER`,
  `DEBUG_ERRORS`, `DEV_ROUTES`
- `plug_cowboy`, `poison`, `ex_json_schema`; `react-router-dom`, `vite-tsconfig-paths`,
  `vite-plugin-dts`, `autoprefixer`, `clsx`, the legacy ESLint plugins and configuration
- Four redundant database indexes on the join tables

### Fixed
- Path traversal in the frontend server (`..` in `/app/<name>/...` read files outside the app);
  a missing asset answered 200 with `index.html`, a directory a 500
- Tokens without `exp`, refresh tokens and tokens of another issuer were accepted; a token without
  `sub` or of a deleted user caused 500s
- Login: timing difference between unknown and known emails, 500 on non-string credentials
- `Admin@example.com` and `admin@example.com` could be two accounts; emails with a trailing newline were
  accepted
- Any user with `roles:assign` could grant themselves `admin`; any user with
  `permissions:assign` could grant any permission
- The last administrator could be removed or deleted, and system roles deleted
- Role hierarchies with cycles or a role that is its own parent; a permission that is its own
  parent; deleting a parent permission was a 500
- 500s on over-long names and slugs, invalid slugs accepted, `assigned_by` without a foreign key
- Concurrent removals of the same assignment raised `StaleEntryError`
- Listings had no stable order
- `"user:<id>"` joins and unknown channel events crashed the channel
- Validation errors of roles, permissions and users answered `"Unprocessable Content"` without the
  field
- The JWT signing key committed in `config/config.exs` was used whenever `GUARDIAN_SECRET_KEY` was
  missing, in production too
- The installer produced projects whose seeds failed, sharing the template's secrets and salts,
  with a broken frontend generator
- `mix rephi.gen.frontend` wrote invalid `package.json` files and always used port 5010
- `setup.sh` hid errors and did not build the apps
- The example app subscribed to `user:lobby` twice (every notification toasted twice)
- `PhoenixSocket` could open two transports, and reconnected with the token of the first connect
- `yarn lint` ran no linter (legacy ESLint configuration)

### Security
- The JWT signing key that was committed to this repository (and to every project generated
  from it) is public: tokens signed with it are rejected everywhere, and every deployment needs its
  own `GUARDIAN_SECRET_KEY`
- See Fixed: path traversal, token validation, privilege escalation through assignments, rate
  limiting, revocable sessions, HTTPS and security headers in production, Swagger off in
  production

### Upgrading from 0.1.0

For a project generated from 0.1.0 (or 0.0.2). Read **Breaking** above first; the steps below are
the ones that touch data or configuration.

1. **Run the new migrations** (`mix ecto.migrate`, or `bin/migrate` in a release). They add
   `users.token_version`, `is_system` on roles and permissions, the checks against self-parenting
   roles and permissions, the `assigned_by` foreign keys, the case-insensitive unique email index,
   and drop four redundant indexes. `20261116120000` refuses to run, without changing anything, if
   two users share an email up to case or a user has no email or password hash: it lists their
   ids; resolve them and run it again.
2. **Run the seeds once** (`mix run priv/repo/seeds.exs`, or `bin/seed` with `ADMIN_EMAIL` and
   `ADMIN_PASSWORD`). They add `notifications:broadcast`, grant `users:view` to `manager` and mark
   the seeded roles and permissions as system records (until then those can be deleted).
3. **Revoke `user → users:view`** if the seeds print it in their NOTICE. Otherwise every user with
   the `user` role can list users, now that `/api/users` checks `users:view` instead of the `admin`
   role: `DELETE /api/roles/<user role id>/permissions/<users:view id>` as an administrator, or
   `Rephi.Authorization.remove_permission_from_role(role, permission)`.
4. **Existing users have no role**: only new accounts get `user`. To give it to every user without
   roles:
   ```sql
   INSERT INTO user_roles (user_id, role_id, inserted_at, updated_at)
   SELECT u.id, r.id, now(), now()
   FROM users u CROSS JOIN roles r
   WHERE r.slug = 'user'
     AND NOT EXISTS (SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id)
   ON CONFLICT DO NOTHING;
   ```
5. **Regenerate the secrets the old installer committed**: the `secret_key_base` and Guardian
   `secret_key` of `config/dev.exs` and `config/test.exs` (`mix phx.gen.secret`), and both
   `signing_salt` values (`config/config.exs` and `lib/<app>_web/endpoint.ex`;
   `mix phx.gen.secret 32`). Remove any `secret_key` from `config/config.exs`: production reads
   `GUARDIAN_SECRET_KEY` only. Every token issued so far becomes invalid.
6. **Production environment**: set `DATABASE_URL`, `SECRET_KEY_BASE`, `GUARDIAN_SECRET_KEY`
   (`mix guardian.gen.secret`) and `PHX_HOST`; add the origins of frontends hosted elsewhere to
   `CORS_ORIGINS`; behind a reverse proxy, make it send `X-Forwarded-Proto` (or set
   `FORCE_SSL=false`) and set `RATE_LIMIT_TRUSTED_PROXIES` to the number of proxies. Set
   `SWAGGER_ENABLED=true` if you want the documentation served in production.
7. **Code that used** `plug AuthorizationPlug, {:role, "admin"}` to protect user management now
   needs the `users:*` permissions (the seeded `admin` has them all). Replace the removed functions
   listed under **Removed**, and `Rephi.Accounts.UserRole` / `UserPermission` with
   `Rephi.Authorization.UserRole` / `UserPermission`.
8. **Frontends**: read responses under `data` and errors under `errors`; treat any 401 as the end
   of the session; call `POST /api/users/logout` on logout; store the new token returned by
   `PUT /api/me/password`; paginate with `meta`; authorize the users panel by `users:*`; send the
   socket token as `authToken` and stop using `shout`; handle 409 and 429. With
   `@rephi/shared-components`, call `configureRephi()` before the first request and move each
   app's base path and port to `apps/<app>/app.config.ts`. Reinstall the installer with
   `mix archive.install github thotenn/rephi --sparse installer`.

## [0.1.0] - 2025-06-23

### Added
- New Mix task `mix rephi.gen.frontend [front_name]` for generating frontend applications
  - Automatically copies the example frontend template
  - Updates router.ex with the new frontend route
  - Streamlines the process of adding new frontend applications to the multi-frontend architecture

### Fixed
- Router catch-all routes moved to end to prevent unreachable routes warning

## [0.0.2] - 2024-06-22

### Added
- Initial release
- JWT authentication system with Guardian
- Complete RBAC (Role-Based Access Control) implementation
- WebSocket support with Phoenix Channels
- Multi-frontend architecture support
- Swagger/OpenAPI documentation
- CSRF protection for SPAs
- Default roles and permissions seeding
- Frontend build integration with Mix tasks
- Dashboard, Admin, E-commerce, and Landing page structure

### Security
- JWT tokens include user roles and permissions
- CSRF token injection in SPA HTML
- WebSocket connections validate JWT tokens
- Hierarchical permission system

No version has been tagged in Git yet; the links below point to the commits of each release.

[0.1.0]: https://github.com/thotenn/rephi/compare/98a3edd...ae597e7
[0.0.2]: https://github.com/thotenn/rephi/tree/98a3edd
