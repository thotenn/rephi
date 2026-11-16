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
mix phx.server               # API on :4000; apps at /app/<name>/, Swagger UI at /api/swagger
mix precommit                # what CI runs: format check, warnings as errors, unused deps, tests
mix test path/to/test.exs:42 # one test
mix test --cover             # threshold 90 % (mix.exs)
mix openapi.spec.json --spec RephiWeb.ApiSpec --start-app=false  # export openapi.json (optional)
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
  accounts/accounts.ex, user.ex    Accounts: register_user (default role), change_password, revoke_tokens
  authorization.ex                 RBAC context: load_access, can?, has_role?, assign_*/remove_*, preserving_admins
  authorization/                   Role, Permission, UserRole, UserPermission, RolePermission, RoleRole, Access
  seeds.ex                         default roles/permissions/admin as data (@roles, @permissions); run/1
  release.ex                       migrate/0, seed/0 for bin/migrate, bin/seed
  pagination.ex, health.ex, repo.ex (fetch/2, cast_id/1)
lib/rephi_web/
  router.ex                        /api (pipelines :api, :authenticated, :api_docs), /app forward
  auth/                            Guardian, Pipeline, AuthorizationPlug, AuthorizationHelpers, ErrorHandler
  controllers/                     *_controller.ex + *_json.ex views, FallbackController, ControllerHelpers
  api_spec.ex                      the OpenAPI 3 document (paths from the router, schemas, bearerAuth)
  api_spec/operations.ex           helpers for `operation`: bearer_auth, id_param, page_params, body, responses
  schemas.ex, schemas/*.ex         RephiWeb.Schemas.* (one module per body) + data/page/timestamp helpers
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
- assignments always get `actor: current_access(conn)` (escalation checks, `assigned_by`);
- anything that can remove the admin role from someone goes through
  `Authorization.preserving_admins/1`;
- anything that must end sessions calls `Accounts.revoke_tokens/1` (bumps `token_version`,
  broadcasts `"disconnect"` on `Accounts.socket_id/1`).

**Seeds.** Data in `Rephi.Seeds` (`@roles`, `@permissions`, `@role_hierarchy`): a new default
permission is one line; seeding is idempotent, insert-only, and marks seeded rows `is_system`.
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
4. OpenAPI: an `operation` next to the action (see "Documenting an endpoint" below); a schema
   module per new body in `lib/rephi_web/schemas/`.
5. Add the requests that produce each documented status to `cases/1` of
   `test/rephi_web/api_contract_test.exs` (it fails on undocumented routes, undocumented
   statuses, and on fields missing from or extra to the schema). 400/401/403/404/413/429 are
   generated from the document; write the 2xx, 409 and 422 ones.
6. Tests with `RephiWeb.ConnCase`; if the endpoint is hot, a query budget in
   `test/rephi_web/query_budget_test.exs`.

## Documenting an endpoint (OpenAPI 3, `open_api_spex`)

`RephiWeb.ApiSpec` reads the paths from the router: a route is documented when its controller
declares an `operation` for the action. The document is served at `/api/openapi` (Swagger UI at
`/api/swagger`); no file is generated. Example, `POST /api/things/:id/archive`:

```elixir
# lib/rephi_web/schemas/things.ex - one module per body; the last segment is the component name
defmodule RephiWeb.Schemas.Thing do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        name: %Schema{type: :string},
        archived_at: RephiWeb.Schemas.timestamp(nullable: true)
      },
      required: [:id, :name, :archived_at]  # responses: EVERY property, nullable ones too
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.ThingResponse do
  require OpenApiSpex
  OpenApiSpex.schema(RephiWeb.Schemas.data(RephiWeb.Schemas.Thing), struct?: false)
end

# the controller
use OpenApiSpex.ControllerSpecs
import RephiWeb.ApiSpec.Operations
alias RephiWeb.Schemas

tags ["Things"]            # declared in @tags of RephiWeb.ApiSpec
security bearer_auth()     # every action needs a token; otherwise `security:` per operation

operation :archive,
  summary: "Archive a thing",
  description: "Requires things:archive.",
  parameters: [id_param(:id, "Thing ID")],
  request_body: body("Optional notes", Schemas.AssignmentNotes, required: false),
  responses:
    responses([
      :unauthorized,       # 401 (every authenticated operation)
      :body_errors,        # 400 + 413 (every operation that reads a body)
      ok: {"Archived", Schemas.ThingResponse},
      forbidden: "Forbidden - requires things:archive",
      not_found: "Thing not found",
      conflict: "Already archived",
      unprocessable_entity: "notes is not a string"
    ])

def archive(conn, %{"id" => id}), do: ...
```

- `responses/1`: an error is just its description (`ErrorResponse`; `ValidationErrors` for 422;
  `ErrorResponse` + `retry-after` for 429); `"..."` on a 2xx is a response without a body
  (`no_content: "Deleted"`); `{"desc", Schema}` / `{"desc", Schema, headers: ...}` is a JSON body.
  Other standard entries: `:invalid_page` (422 of `page_params()`), `:too_many_requests`.
- Envelopes: `RephiWeb.Schemas.data(schema)` (`{"data": ...}`), `page(item)` (`data` + `meta`).
  Nullable: `nullable: true` (OpenAPI 3.0), never `x-nullable`; not on a `$ref` (inline the
  object instead).
- PUT and PATCH of `resources` share one `operation :update`; `RephiWeb.ApiSpec` gives PATCH
  the id `<Controller>.update.patch`.
- Request bodies are not cast nor validated by the spec (no `CastAndValidate`): the controller
  validates and the `FallbackController` answers. Do not add it to one controller only.
- Formatting: `:open_api_spex` is in `import_deps`, so `operation`/`tags`/`security` take no
  parentheses.

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
  `{result, count}`. Login 2, `/api/me` 2, `/api/roles/:id` 4: if a number grows, something
  queries per check again.
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

## Traps

- `mix setup` does not build frontends; `./setup.sh` does. A fresh clone needs
  `yarn shared:build` before `typecheck`, `lint` or any app.
- `.env` is loaded in development only (`config/dotenv.exs`) and never overrides the shell;
  `mix test` reads no environment variable (`config/test.exs` is the whole configuration).
- Production refuses to boot without `DATABASE_URL`, `SECRET_KEY_BASE`, `GUARDIAN_SECRET_KEY`
  (>= 32 bytes) and `PHX_HOST`; `CORS_ORIGINS` with `*` also stops the boot.
- `FORCE_SSL` is on in prod: a local prod smoke over plain HTTP gets 301s except on
  `localhost` / `127.0.0.1` and `/api/health*`.
- The API documentation (`/api/openapi`, `/api/swagger`) is off in prod unless
  `SWAGGER_ENABLED=true` (404 otherwise). The document is cached after the first request
  (persistent_term) except in dev (`NoneCache` in `config/dev.exs`).
- A changed `config/*.exs` needs a server restart (Phoenix does not reload config).
- Client routes of a SPA must not end in something extension-like (`/users/john.doe` is a 404).
- A controller that `use OpenApiSpex.ControllerSpecs` warns at runtime ("No operation spec
  defined") for a routed action without `operation`; the contract test fails on it.
- The Swagger UI route is not under `:api` (its HTML needs a CSP that allows its CDN scripts);
  `/api/openapi` is, with the strict CSP.
- The installer refuses to generate if the template does not have exactly the expected
  secrets and salts (2 `secret_key_base`, 2 Guardian `secret_key`, 2 `signing_salt`): keep that
  shape when touching `config/*.exs` or `endpoint.ex`.
- Repo is public: no real hosts, IPs or personal paths in code, comments or docs.
