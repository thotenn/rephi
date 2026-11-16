# Rephi

A Phoenix boilerplate for JSON APIs with JWT authentication, role-based access control (RBAC),
real-time notifications over Phoenix Channels, and any number of frontends in a Yarn workspace:
React single-page apps served by Phoenix, or static sites hosted anywhere.

- **API** - Phoenix 1.8 JSON API under `/api`, one response and error envelope, paginated lists,
  Swagger documentation checked against the real endpoints
- **Authentication** - JWT access tokens (24 hours) that can be revoked: logout on every device,
  password change, deleted users; rate-limited login and registration
- **RBAC** - hierarchical roles, permissions, system records, protection against privilege
  escalation and against losing the last administrator; checks cost no query inside a request
- **Realtime** - an authenticated socket with a broadcast topic and a private topic per user
- **Frontends** - `@rephi/shared-components` (the only code that talks to the backend), a React
  SPA example served by Phoenix at `/app/example/`, the same app as a static Astro site for
  Cloudflare Pages, and `mix rephi.gen.frontend` to add more
- **Operations** - health checks, a `Dockerfile`, release commands to migrate and seed, CI,
  `mix precommit`

## Contents

- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Configuration](#configuration)
- [Authentication](#authentication)
- [Authorization (RBAC)](#authorization-rbac)
- [The API](#the-api)
- [Realtime](#realtime)
- [Frontends](#frontends)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Upgrading an existing project](#upgrading-an-existing-project)

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Elixir | 1.20.5 | `.tool-versions`; `./setup.sh` requires at least this version |
| Erlang/OTP | 29.1.2 | `.tool-versions`; `./setup.sh` requires OTP 29 or newer |
| Node.js | 22.22 or newer | `engines` in `package.json`; developed on 26.13.1 (`.tool-versions`) |
| Yarn | 4.18 | Through Corepack (`packageManager` in `package.json`): `corepack enable`. Node.js 25 and newer no longer bundle Corepack: `npm install -g corepack` first |
| PostgreSQL | any supported release | CI runs 17. Development expects `postgres` / `postgres` on `localhost` unless told otherwise (see [Configuration](#configuration)) |

## Getting started

### A new project, with the installer

The installer is a Mix archive built from the `installer/` directory of this repository (it is not
published on Hex):

```bash
mix archive.install github thotenn/rephi --sparse installer
mix rephi.new my_app
cd my_app
./setup.sh
mix phx.server
```

`mix rephi.new` clones the template, renames the application and its modules (`my_app` /
`MyApp`), gives the project its own development and test secrets and signing salts, fetches the
dependencies and commits everything on `main`. `mix help rephi.new` lists `--app`, `--module`,
`--no-install`, `--no-git`, `--from` and `--branch`; [`installer/README.md`](installer/README.md)
has the details.

### Working on Rephi itself, from a clone

```bash
git clone https://github.com/thotenn/rephi.git
cd rephi
./setup.sh
mix phx.server
```

`./setup.sh` stops at the first error, works from any directory and can be run again after a
pull. It:

1. checks Elixir and Erlang/OTP (`.tool-versions`), Node.js (`engines`), Yarn 4 through Corepack
   and that PostgreSQL answers;
2. writes a git-ignored `.env` with a new `SECRET_KEY_BASE` and `GUARDIAN_SECRET_KEY` for
   development (`elixir scripts/dev_env.exs`; existing values are kept);
3. runs `mix setup`: dependencies, database, migrations, seeds and `swagger.json`;
4. runs `yarn install`, `yarn shared:build` and `yarn build`, which copies the apps into
   `priv/static/apps/`.

Then open:

- `http://localhost:4000/app/example/` - the example SPA, served by Phoenix
- `http://localhost:4000/api/swagger` - the API documentation
- `http://localhost:4000/api/health` - the liveness check

The development seeds create the administrator `admin@admin.com` / `password123!!` when
`ADMIN_EMAIL` and `ADMIN_PASSWORD` are not set (and say so). Never expose that database.

The same steps by hand (`mix setup` prepares the Phoenix side only):

```bash
mix setup                 # deps, database, migrations, seeds, swagger.json
yarn install
yarn shared:build         # required before any app
yarn build                # every app, copied to priv/static/apps/
mix phx.server
```

## Configuration

Everything that changes between environments comes from environment variables, read at boot by
`config/runtime.exs`. [`.env.example`](.env.example) documents each one.

- **Development** reads a git-ignored `.env` file (`config/dotenv.exs`): `KEY=value`, optional
  `export`, quotes and comments. Variables already set in the shell win. Without a `.env`,
  `config/dev.exs` has working defaults.
- **Test** reads no variable and no `.env`: `config/test.exs` is the whole configuration.
- **Production** reads the real environment only. An empty variable counts as unset; a missing
  required variable stops the boot with a message that says how to generate it.

| Variable | Purpose | Development | Production | Required in prod |
|---|---|---|---|---|
| `DATABASE_URL` | Database, `ecto://USER:PASS@HOST/DATABASE` | not read (see `DB_*`) | - | **yes** |
| `SECRET_KEY_BASE` | Signs and encrypts cookies (`mix phx.gen.secret`) | value in `config/dev.exs`; `./setup.sh` writes one to `.env` | - | **yes** |
| `GUARDIAN_SECRET_KEY` | Signs every JWT (`mix guardian.gen.secret`) | value in `config/dev.exs`; `./setup.sh` writes one to `.env` | - | **yes**, at least 32 bytes |
| `PHX_HOST` | Public host name: URLs and the WebSocket origin check | `localhost` | - | **yes** |
| `PORT` | HTTP port | `4000` | `4000` | no |
| `DB_USERNAME` / `DB_PASSWORD` / `DB_HOSTNAME` / `DB_NAME` / `DB_POOL_SIZE` | Development database | `postgres` / `postgres` / `localhost` / `rephi_dev` / `10` | not read | no |
| `POOL_SIZE` | Database pool size | not read | `10` | no |
| `ECTO_IPV6` | Connect to the database over IPv6 (`true`/`1`) | not read | off | no |
| `DNS_CLUSTER_QUERY` | DNS name of the other nodes of a cluster | not read | none | no |
| `PHX_SERVER` | Start the HTTP server in a release (`bin/server` sets it) | - | unset | no |
| `TOKEN_TTL_SECONDS` | Lifetime of an access token | `86400` | `86400` | no |
| `CORS_ORIGINS` | Browser origins allowed to call the API, comma separated: exact origins or `https://*.example.com` wildcards, never `*` | the local dev servers (`:cors_origins` in `config/dev.exs`) | none | no |
| `CHECK_ORIGIN` | WebSocket origin check: `true`, `false` or a list of origins | off | `PHX_HOST` plus `CORS_ORIGINS` | no |
| `FORCE_SSL` | Redirect HTTP to HTTPS and send HSTS; the scheme comes from `X-Forwarded-Proto`; `/api/health*` and `localhost` are never redirected | not read (off) | `true` | no |
| `SWAGGER_ENABLED` | Serve `/api/swagger` and `swagger.json` | `true` | `false` | no |
| `RATE_LIMIT_ENABLED` | Throttle login, password change and registration | `true` | `true` | no |
| `RATE_LIMIT_LOGIN_MAX` / `RATE_LIMIT_REGISTER_MAX` / `RATE_LIMIT_WINDOW_SECONDS` | Requests per window and client IP | `10` / `5` / `60` | `10` / `5` / `60` | no |
| `RATE_LIMIT_TRUSTED_PROXIES` | Reverse proxies whose `X-Forwarded-For` entry gives the client IP | `0` (header ignored) | `0` | no |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | First administrator, created by the seeds | `admin@admin.com` / `password123!!` when unset | - | **yes, to seed** |

Settings that are code rather than environment live in `config/config.exs`:

| Key | Default | What it does |
|---|---|---|
| `config :rephi, Rephi.Authorization, admin_role:` | `"admin"` | The administrator role: at least one user always keeps it, and its holders may grant any role or permission and manage any user |
| `config :rephi, Rephi.Accounts, default_role:` | `"user"` | The role every new account gets; `nil` gives none |
| `config :rephi, RephiWeb.Notifications, max_message_length:` | `500` | Longest broadcast message, in characters |
| `config :rephi, RephiWeb.Plugs.RateLimit, ...` | see the file | Buckets, limits and windows of the rate limiter |

## Authentication

- `POST /api/users/register` creates an account (email, password of 8 characters to 72 bytes) with
  the default role and returns a session: `{"data": {"user": {...}, "token": "..."}}`.
- `POST /api/users/login` exchanges credentials for a session.
- Send the token as `Authorization: Bearer <token>`. `GET /api/me` returns the signed-in user:
  `{id, email, must_change_password, roles, permissions}`, where `roles` are the ones assigned to the user and
  `permissions` its effective permissions (direct, through roles and inherited). Register, login
  and the password change describe the user the same way.
- **Tokens** are access tokens that last 24 hours (`TOKEN_TTL_SECONDS`); there is no refresh token.
  Each one carries the user's `token_version` (`ver` claim): logging out, changing the password or
  deleting the user increments it, which invalidates every token issued before and closes the
  user's WebSockets. A revoked, expired or malformed token is a `401`.
- `POST /api/users/logout` (204) logs out **every** device of the user.
- `PUT /api/me/password` with `current_password` and `password` (and optionally
  `password_confirmation`) returns a new session; the previous token stops working.
- Emails are stored trimmed and lowercased: `Jane@Example.com` and `jane@example.com` are the same
  account.
- **Rate limits** per client IP: 10 requests per minute to login and to the password change
  (they share a counter), 5 registrations per minute. Past the limit: `429` with a `retry-after`
  header. The counters live in memory, per node. Behind a reverse proxy see
  `RATE_LIMIT_TRUSTED_PROXIES` in [Deployment](#reverse-proxies).
- **Password reset by an administrator.** `POST /api/users/:id/password` (permission
  `users:reset_password`, seeded for `admin` only) replaces another user's password with a random
  temporary one, returned once in that response (`cache-control: no-store`; only its hash is
  stored). Every session of the user ends (tokens revoked, sockets closed) and the account is
  flagged `must_change_password`: the user signs in with the temporary password, and until it sets
  a new one with `PUT /api/me/password` every other route but `GET /api/me` and logout answers
  `403`. Nobody chooses another user's password, and your own is changed with
  `PUT /api/me/password` (`409` here).

## Authorization (RBAC)

### What the seeds create

`mix run priv/repo/seeds.exs` (part of `mix setup` and `mix ecto.setup`), or `bin/seed` in a
release, runs `Rephi.Seeds.run/1`. It is idempotent and transactional, never changes what already
exists (an administrator's password included) and marks the seeded roles, permissions and
hierarchy links as **system records**.

- **3 roles**: `admin` inherits from `manager`, which inherits from `user`.
- **19 permissions**: `users:view|create|edit|delete|reset_password`,
  `roles:view|create|edit|delete|assign`, `permissions:view|create|edit|delete|assign`,
  `system:settings|logs|manage` and `notifications:broadcast`.
- **Grants**: `admin` holds every permission. `manager` holds `users:view`, `users:create`,
  `users:edit` and `roles:view`. `user` holds none (it is the role every new account gets).
- **The first administrator** from `ADMIN_EMAIL` / `ADMIN_PASSWORD`: required outside
  development, where `admin@admin.com` / `password123!!` is used instead.

When the seed stops granting something an older version granted, it reports the grant and prints
how to revoke it; it never revokes anything itself.

### Rules

- Holding a role means holding its ancestors: an `admin` is also a `manager` and a `user`, and
  holds their permissions. A permission's `parent_id` only groups permissions for display: holding
  the parent grants none of its children.
- **System records** (`is_system`) cannot be deleted (`409`) nor change slug (`422`); their name
  and description can change. The links of the default hierarchy (`admin → manager → user`) are
  system links: they cannot be removed (`409`).
- **The hierarchy** is managed over the API (`roles:edit`): a link that would make a role inherit
  from itself is refused (`409`), and linking or unlinking a parent requires holding both roles,
  unless the caller is an administrator (`403`).
- **No escalation**: granting or revoking a role requires holding it, and a permission (to a role
  or directly to a user) requires holding that permission, unless the caller is an administrator
  (`403`). Editing, deleting or resetting the password of a user who holds roles the caller does
  not hold is a `403` too.
- **Direct permissions** are revoked from the user; one the user only holds through a role is
  refused (`409`), like a permission a role only inherits.
- **The last administrator** cannot lose the admin role, directly, through a deleted role or
  through an unlinked parent (`409`), and nobody can delete their own account or reset their own
  password (`409`).
- Slugs: roles `editor`, `content_editor`, `team-lead`; permissions `category:action`
  (`reports:export`).

### Checking permissions in code

`RephiWeb.Auth.Pipeline` loads the signed-in user and its `Rephi.Authorization.Access` (roles and
effective permissions, in one query) once per request into `conn.assigns.current_user` and
`conn.assigns.current_access`. Every check below reads that access and costs no query.

Guard whole actions with `AuthorizationPlug` (from `RoleController`):

```elixir
plug AuthorizationPlug,
     {:permission, "roles:view"} when action in [:index, :show, :get_role_permissions]

plug AuthorizationPlug, {:permission, "roles:create"} when action in [:create]
```

Other forms: `{:any_permission, [...]}`, `{:all_permissions, [...]}` and `{:role, "manager"}`
(follows the hierarchy). Prefer permissions: a role check hard-codes who may do something, a
permission can be granted to any role later. A missing permission is a `403`.

Inside an action, `use RephiWeb, :controller` imports `can?/2`, `can_any?/2`, `can_all?/2`,
`has_role?/2` and `current_access/1`:

```elixir
def show(conn, %{"id" => id}) do
  with {:ok, report} <- Reports.fetch_report(id) do
    render(conn, :show, report: report, can_edit: can?(conn, "reports:edit"))
  end
end
```

Pass the caller to the assignment functions so the escalation rules apply (from
`RoleController.assign_to_user/2`):

```elixir
Authorization.assign_role_to_user(user, role, actor: current_access(conn), notes: params["notes"])
```

Outside a request (a context, a job, a channel), use `Rephi.Authorization` directly:
`can?(user, "reports:edit")` costs one query; `access = load_access(user)` and then
`can?(access, ...)` for several checks.

## The API

The interactive documentation is at `/api/swagger` and the document at
`/api/swagger/swagger.json` (Swagger 2.0), both on in development and off in production unless
`SWAGGER_ENABLED=true`. `swagger.json` is a build artifact: `mix phx.swagger.generate` writes it
to `priv/static/swagger.json` (`mix setup` and the `Dockerfile` run it).
`test/rephi_web/swagger_contract_test.exs` fails when a route is not documented or a documented
response is not what the endpoint answers.

| Area | Endpoints | Permission |
|---|---|---|
| Service | `GET /`, `GET /api/health`, `GET /api/health/ready` | none |
| Auth | `POST /api/users/register`, `POST /api/users/login` | none |
| | `GET /api/me`, `PUT /api/me/password`, `POST /api/users/logout` | signed in |
| Users | `GET /api/users`, `GET /api/users/:id`, `GET /api/users/:id/roles`, `GET /api/users/:id/permissions` | `users:view` |
| | `PUT/PATCH /api/users/:id` (email only) | `users:edit` |
| | `DELETE /api/users/:id` | `users:delete` |
| | `POST /api/users/:id/password` (temporary password) | `users:reset_password` |
| Roles | `GET /api/roles`, `GET /api/roles/:id`, `GET /api/roles/:id/permissions`, `GET /api/roles/:id/parents`, `GET /api/roles/:id/children` | `roles:view` |
| | `POST /api/roles`, `PUT/PATCH /api/roles/:id`, `DELETE /api/roles/:id` | `roles:create` / `roles:edit` / `roles:delete` |
| | `POST/DELETE /api/roles/:role_id/parents/:parent_id` | `roles:edit` |
| | `POST/DELETE /api/users/:user_id/roles/:role_id` | `roles:assign` |
| Permissions | `GET /api/permissions`, `GET /api/permissions/:id` | `permissions:view` |
| | `POST /api/permissions`, `PUT/PATCH /api/permissions/:id`, `DELETE /api/permissions/:id` | `permissions:create` / `permissions:edit` / `permissions:delete` |
| | `POST/DELETE /api/roles/:role_id/permissions/:permission_id` | `permissions:assign` |
| | `POST/DELETE /api/users/:user_id/permissions/:permission_id` | `permissions:assign` |
| Notifications | `POST /api/notifications/broadcast` | `notifications:broadcast` |

**Envelopes.** A successful response with a body is `{"data": ...}`. Lists of users, roles and
permissions are paginated with `page` (from 1) and `page_size` (default 50, at most 100):

```json
{"data": [...], "meta": {"page": 1, "page_size": 50, "total": 120, "total_pages": 3}}
```

Every error is `{"errors": {"detail": "Not Found"}}`, or for a validation error (422) one list of
messages per field: `{"errors": {"slug": ["has already been taken"]}}`. Write endpoints accept
their attributes flat (`{"name": "Editor", "slug": "editor"}`) or wrapped under the resource name
(`{"role": {...}}`).

| Status | Meaning |
|---|---|
| `400` | Malformed JSON; login without email or password |
| `401` | Missing, invalid, expired or revoked token; wrong credentials |
| `403` | Missing permission, granting/changing what the caller does not hold, or a password reset not yet replaced |
| `404` | Unknown record (also an id that is not a positive integer) or route |
| `409` | The change conflicts with the data: duplicate assignment, system record or link, last administrator, own account, inherited permission, cycle in the role hierarchy |
| `413` | Body over 1 MB |
| `422` | Invalid fields |
| `429` | Rate limited; wait `retry-after` seconds |
| `503` | `GET /api/health/ready`: the database does not answer |

Responses carry `x-content-type-options: nosniff`, a `default-src 'none'` content security
policy and a referrer policy. Unknown paths answer a JSON `404`; the backend has no HTML pages of
its own.

## Realtime

The socket is at `/socket` (`ws://localhost:4000/socket` in development). It needs the same access
token as the API, preferably as Phoenix's `authToken`, which travels in the
`Sec-WebSocket-Protocol` header and never in a URL:

```js
import { Socket } from "phoenix";

const socket = new Socket("/socket", { authToken: token });
socket.connect();
socket.channel("user:lobby").join();
```

The legacy `params: {token}` form still works. A missing, invalid, expired or revoked token
refuses the connection, and the server closes every socket of a user who logs out, changes the
password or is deleted.

| Topic | Who may join | What arrives |
|---|---|---|
| `user:lobby` | any authenticated socket | broadcasts |
| `user:<id>` | only the user with that id (others get `{"reason": "unauthorized"}`) | notifications for that user |

The server pushes `new_notification` with
`{"message", "timestamp", "type": "general", "from": {"id", "email"} | null}` (`null` when the
system sends it). Render `message` as text. Clients cannot broadcast: the only client event is
`ping` (echoed back); anything else gets an `unknown_event` error reply.

`POST /api/notifications/broadcast` (`{"message": "..."}`, 1 to 500 characters, permission
`notifications:broadcast`, only `admin` holds it by default) sends to `user:lobby`. From Elixir,
`RephiWeb.Notifications.broadcast/2` and `notify_user/3` send the same event.

## Frontends

```
apps/
├── example/              React SPA (Vite), served by Phoenix at /app/example/
├── example-astro/        The same app as a static Astro site, for Cloudflare Pages
└── <your apps>/          mix rephi.gen.frontend
packages/
└── shared-components/    @rephi/shared-components: the only code that talks to the backend
priv/static/apps/         Builds Phoenix serves (yarn build)
```

### `@rephi/shared-components`

The HTTP client, the session, the socket and channels, permission checks for the UI and the types
of the API contract. Each app calls `configureRephi({apiUrl, wsUrl, debug})` once, before the first
request; nothing is inlined when the library is built. Its
[README](packages/shared-components/README.md) documents the API: `login` / `register` /
`logout` / `changePassword`, `ApiError` and `describeError`, `onSessionEnd` (any 401 on the
current token ends the session), `PhoenixSocket`, `useChannel`, `usePermissions`,
`PermissionGuard`, `fetchPage` / `fetchAllPages`.

Build it before starting, linting or type-checking any app: the apps import its compiled `dist/`.

```bash
yarn shared:build
```

### The two example apps

- [`apps/example`](apps/example) - a Vite + React SPA (React Router, TanStack Query,
  React Hook Form + Zod, Tailwind CSS 4; the session lives in the library's Zustand store):
  login, registration, profile with password change, dashboard, admin screens for users, roles
  and permissions, and live notifications. It configures the
  library in `src/lib/rephi.ts`: under `vite dev` the API is `http://localhost:4000/api`, in a
  build it is the same origin (`/api`, `/socket`); `VITE_API_URL` / `VITE_WS_URL` override both
  (`apps/example/.env.example`).
- [`apps/example-astro`](apps/example-astro/README.md) - the same app as prerendered Astro pages
  with React islands, meant for a static host. Its API and socket URLs are `PUBLIC_API_URL` /
  `PUBLIC_WS_URL`, and the backend must allow its origin in `CORS_ORIGINS` (CORS and the socket).
  Its README covers the architecture, the variables, deploying to Cloudflare Pages (Git
  integration or `wrangler pages deploy`) and serving it from Phoenix instead.

Each app keeps the settings that depend on where it runs in `apps/<app>/app.config.ts`:

```ts
export const appConfig = {
  basename: "/app/example",   // the Astro app: "/"
  port: 5001,                 // dev server; the Astro app: 4321
} as const;
```

### How Phoenix serves an app

Every directory `priv/static/apps/<name>` is served at `/app/<name>/` by
`RephiWeb.Plugs.FrontendAppPlug`, without touching the router. `<name>` is lowercase letters,
digits, `-` and `_`. Inside an app:

1. the file itself, if it exists;
2. for a path without an extension, a directory with an `index.html`: `/app/x/login/` serves
   `login/index.html`, and `/app/x/login` redirects (`301`) to the trailing slash;
3. otherwise, a path **with** an extension is a JSON `404`; if the app has a `404.html` at its
   root it is a **multi-page site** and that page is served with a `404`; if not, it is a
   **single-page app** and the path gets its `index.html` (client-side routes survive a reload).

So a SPA must **not** ship a root `404.html`, and its client routes cannot end in something that
looks like an extension (`/users/john.doe`). Only `GET` and `HEAD` are answered, dotfiles are
never served, `assets/` (Vite) and `_astro/` (Astro) are cached as immutable and everything else
revalidates with its `ETag`.

`yarn build` builds every workspace and ends with `scripts/copy-builds.js`, which replaces each
`priv/static/apps/<app>` with `apps/<app>/dist` (and fails when an app has no build). An app
deployed elsewhere opts out in its `package.json` (the Astro app does):

```json
"rephi": { "copyToPhoenix": false }
```

`node scripts/copy-builds.js --app NAME` copies one app, opted out or not.

### Adding an app

```bash
mix rephi.gen.frontend dashboard                          # a Vite SPA copied from apps/example
mix rephi.gen.frontend admin-panel --port 5020            # choose the dev server port
mix rephi.gen.frontend site --template example-astro      # a static Astro site
```

The generator checks everything before writing anything, so a refused run changes nothing. It
creates `apps/NAME/` (package `rephi-NAME`), sets `basename` (`/app/NAME` for a Vite app; an
Astro site keeps `/`) and a free `port` in its `app.config.ts`, adds the `NAME:dev` and
`NAME:build` scripts to `package.json` and the dev server's origin to `:cors_origins` in
`config/dev.exs`. Nothing in `packages/` or the router changes. Then:

```bash
yarn install
yarn shared:build
yarn NAME:dev              # restart `mix phx.server` first: config/dev.exs changed
yarn build                 # a Vite app is then served at http://localhost:4000/app/NAME/
```

An Astro site keeps `"rephi": {"copyToPhoenix": false}`; the generator prints how to build it for
Phoenix instead. See `mix help rephi.gen.frontend`.

## Development

```bash
mix phx.server               # the API on http://localhost:4000
iex -S mix phx.server        # the same, with a shell
yarn example:dev             # the SPA's dev server, http://localhost:5001/app/example/
yarn example-astro:dev       # the Astro dev server, http://localhost:4321
```

| Command | What it does |
|---|---|
| `mix setup` | Dependencies, database, migrations, seeds and `swagger.json` |
| `mix ecto.reset` | Drop the database and set it up again with the seeds |
| `mix run priv/repo/seeds.exs` | Seed again (idempotent) |
| `mix phx.swagger.generate` | Regenerate `priv/static/swagger.json` after changing a `swagger_path` |
| `mix rephi.gen.frontend NAME` | Add a frontend app |
| `mix format` | Format the Elixir code |
| `mix docs` | Generate the ExDoc documentation |
| `yarn build` | Build every workspace and copy the apps to `priv/static/apps/` |
| `yarn NAME:build` | Build one app (no copy) |
| `yarn lint` / `yarn typecheck` | Lint / type-check every workspace (after `yarn shared:build`) |
| `yarn clean` | Remove every build, `priv/static/apps` included |
| `yarn workspace rephi-example preview` | Preview the SPA's production build |
| `yarn workspace rephi-example-astro pages:dev` | Serve the Astro build with the local Cloudflare Pages emulator |

In development, `/dev/metrics` is the Phoenix LiveDashboard.

## Testing

```bash
mix test                 # the backend suite (creates and migrates the test database)
mix test --cover         # with coverage; fails under the 90 % threshold of mix.exs
mix precommit            # what CI runs: format check, warnings as errors, unused deps, tests
cd installer && mix test # the installer
```

The suite needs PostgreSQL with `postgres` / `postgres` on `localhost` (`config/test.exs`) and
reads no environment variable. Among others it pins the number of database queries of the main
endpoints (`test/rephi_web/query_budget_test.exs`) and checks the Swagger document against the
API (`test/rephi_web/swagger_contract_test.exs`).

CI (`.github/workflows/ci.yml`) runs `mix precommit` against PostgreSQL 17 and the installer's
tests, and, for the frontends, `yarn install --immutable`, `yarn shared:build`,
`yarn typecheck`, `yarn lint` and `yarn build`.

## Deployment

### With Docker

The `Dockerfile` builds the frontends, `swagger.json` and the release into one image. The apps
call `/api` and `/socket` on the origin that serves them.

```bash
docker build -t my_app .

export DATABASE_URL=ecto://USER:PASS@HOST/DATABASE
export SECRET_KEY_BASE="$(mix phx.gen.secret)"
export GUARDIAN_SECRET_KEY="$(mix guardian.gen.secret)"
export PHX_HOST=api.example.com

docker run --rm -e DATABASE_URL -e SECRET_KEY_BASE -e GUARDIAN_SECRET_KEY -e PHX_HOST my_app bin/migrate
docker run --rm -e DATABASE_URL -e SECRET_KEY_BASE -e GUARDIAN_SECRET_KEY -e PHX_HOST \
  -e ADMIN_EMAIL=admin@example.com -e ADMIN_PASSWORD='a-long-passphrase' my_app bin/seed
docker run -p 4000:4000 -e DATABASE_URL -e SECRET_KEY_BASE -e GUARDIAN_SECRET_KEY -e PHX_HOST my_app
```

### Without Docker

```bash
yarn install --immutable && yarn shared:build && yarn build
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix phx.swagger.generate
MIX_ENV=prod mix release

_build/prod/rel/rephi/bin/migrate      # migrations (Rephi.Release.migrate/0)
_build/prod/rel/rephi/bin/seed         # roles, permissions, first admin (Rephi.Release.seed/0)
_build/prod/rel/rephi/bin/server       # starts the HTTP server (PHX_SERVER=true)
```

(`rephi` is the application name; a project made with `mix rephi.new` has its own.)

Run `bin/migrate` and then `bin/seed` (with `ADMIN_EMAIL` and `ADMIN_PASSWORD`) on the first
deployment, and again after an upgrade that adds migrations or default roles and permissions:
both are idempotent. The required variables are `DATABASE_URL`, `SECRET_KEY_BASE`,
`GUARDIAN_SECRET_KEY` and `PHX_HOST`; give every deployment its own secrets. Point the load
balancer at `GET /api/health` (liveness) and `GET /api/health/ready` (readiness).

### Reverse proxies

Production expects TLS to end in a reverse proxy or load balancer:

- **HTTPS** - `FORCE_SSL` (on by default) redirects plain HTTP and sends HSTS, reading the scheme
  from `X-Forwarded-Proto`: the proxy must send it. Set `FORCE_SSL=false` only if something else
  guarantees HTTPS and the redirect gets in the way.
- **Rate limits** - behind a proxy every client has the proxy's address, so they all share one
  counter. If every request goes through your proxies, set `RATE_LIMIT_TRUSTED_PROXIES` to their
  number so the client IP comes from `X-Forwarded-For`; otherwise raise the limits or set
  `RATE_LIMIT_ENABLED=false` and limit at the edge.
- **Other origins** - a frontend served from another origin (a static host, a preview deployment)
  must be in `CORS_ORIGINS`, which also feeds the WebSocket origin check; `CHECK_ORIGIN` overrides
  that check (`true`, `false` or a list).
- **WebSockets** - the proxy must forward the upgrade of `/socket/websocket`.

## Upgrading an existing project

[`CHANGELOG.md`](CHANGELOG.md) lists every change per version, with the breaking ones marked.
Projects created from 0.1.0 follow
[Upgrading from 0.1.0](CHANGELOG.md#upgrading-from-010): new migrations, seeding again, a grant
to revoke, the default role for existing users, secrets to regenerate, new required variables in
production and the client changes.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run `mix precommit` and the frontend checks (`yarn shared:build && yarn typecheck && yarn lint`)
4. Commit your changes and open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
