# Rephi

A production-ready Phoenix boilerplate with JWT authentication, RBAC authorization, WebSocket support, and multi-frontend architecture.

## 🚀 Quick Start

### Create a new project using Rephi

1. **Install the project generator** (a Mix archive built from the `installer/`
   directory of this repository; it is not published on Hex)
   ```bash
   mix archive.install github thotenn/rephi --sparse installer
   ```

2. **Create your project**
   ```bash
   mix rephi.new my_app
   cd my_app
   ```

   It clones the template, renames the application and its modules (`my_app` / `MyApp`),
   gives the project its own secrets and signing salts, fetches the dependencies and creates
   a Git repository with an initial commit. See `mix help rephi.new` for `--app`, `--module`,
   `--no-install` and `--no-git`.

3. **Set it up and run it**
   ```bash
   ./setup.sh
   mix phx.server
   ```

   Open [`localhost:4000/app/example/`](http://localhost:4000/app/example/) (the example
   frontend) and [`localhost:4000/api/swagger`](http://localhost:4000/api/swagger) (the API
   documentation). `./setup.sh` prints the development administrator to log in with.

To work on the generator itself, build and install the archive from a clone:
`cd installer && mix archive.build && mix archive.install rephi_new-*.ez`.

### Prerequisites

- **Elixir** 1.19 or higher (developed on 1.20.5)
- **Erlang/OTP** 28 or higher (developed on 29.1.2)
- **PostgreSQL** 12 or higher
- **Node.js** 22.22 or higher (developed on 26 LTS)
- **Yarn** 4.x through Corepack: run `corepack enable` once. Node.js 25 and newer no longer
  bundle Corepack, so install it first with `npm install -g corepack`

## Features

- **🔐 JWT Authentication**: Secure token-based authentication system
- **👮 RBAC Authorization**: Complete Role-Based Access Control with hierarchical permissions
- **🔌 WebSocket Support**: Real-time communication via Phoenix Channels
- **⚛️ Multi-Frontend Architecture**: Any number of React SPAs served by Phoenix under `/app/<name>/`, generated with `mix rephi.gen.frontend`
- **🚀 Astro Example**: The same example app as a static Astro site, ready for Cloudflare Pages
- **📚 API Documentation**: Auto-generated Swagger/OpenAPI documentation
- **🏗️ Production Ready**: Configured for scalability and best practices
- **🛡️ CSRF Protection**: Built-in CSRF token injection for SPAs

### Manual Setup (for development)

1. **Clone the repository**
   ```bash
   git clone https://github.com/thotenn/rephi.git
   cd rephi
   ```

2. **Run the setup script**
   ```bash
   ./setup.sh
   ```

   It stops at the first error, works from any directory and can be run again after a pull.
   It:
   - checks Elixir and Erlang/OTP (the versions in `.tool-versions` are the minimums), Node.js
     (`engines` in `package.json`), Yarn 4 through Corepack and that PostgreSQL answers;
   - writes a git-ignored `.env` with a new `SECRET_KEY_BASE` and `GUARDIAN_SECRET_KEY` for
     development (`elixir scripts/dev_env.exs`; existing values are kept);
   - runs `mix setup`: dependencies, database, migrations, seeds and `swagger.json`;
   - runs `yarn install`, `yarn shared:build` and `yarn build`, which copies the apps into
     `priv/static/apps/`.

3. **Start the application**
   ```bash
   mix phx.server        # Terminal 1
   yarn example:dev      # Terminal 2 (optional: the Vite dev server)
   ```

   - Example app served by Phoenix: `http://localhost:4000/app/example/`
   - Example app dev server: `http://localhost:5001/app/example/`
   - Swagger UI: `http://localhost:4000/api/swagger`

   The Astro version of the example runs with `yarn example-astro:dev` on
   `http://localhost:4321` (see [`apps/example-astro`](apps/example-astro/README.md)).

#### Alternative: Step-by-step setup

`mix setup` prepares the Phoenix side only; the frontends are built with Yarn:

```bash
mix setup                 # deps, database, migrations, seeds, swagger.json
yarn install
yarn shared:build         # required before any app
yarn build                # every app, copied to priv/static/apps/
mix phx.server
```

Without a `.env`, development uses the defaults in `config/dev.exs`; `.env.example` lists every
setting.

## Frontend Development

The project uses a Yarn workspace monorepo structure with multiple frontend applications.

### Working with Frontend Apps

```bash
# Install dependencies for all apps
yarn install

# IMPORTANT: Build shared-components first (required before running any app)
yarn shared:build

# Start a specific app in development mode
yarn example:dev
yarn example-astro:dev

# Build all apps
yarn build

# Run linting/type checking for all apps
yarn lint
yarn typecheck
```

> **Note:** The `shared-components` package must be built before running any frontend app, as apps import from the compiled `dist/` folder.

### Creating a New Frontend App

```bash
mix rephi.gen.frontend dashboard                          # a Vite SPA copied from apps/example
mix rephi.gen.frontend admin-panel --port 5020            # choose the dev server port
mix rephi.gen.frontend site --template example-astro      # a static Astro site
```

Names use lowercase letters, digits, `_` and `-` (the names Phoenix serves under
`/app/<name>/`). The generator checks everything before writing anything, so a refused run
changes nothing. It creates `apps/NAME/` (package `rephi-NAME`), adds the `NAME:dev` and
`NAME:build` scripts to `package.json`, picks a free dev port and adds its origin to the
development CORS list in `config/dev.exs`. A Vite app also gets its entry in
`packages/shared-components/src/env.ts` (base path and port). The router does not change:
Phoenix serves every directory of `priv/static/apps/`.

Then:

```bash
yarn install
yarn shared:build          # the app reads its base path and port from the shared package
yarn NAME:dev              # dev server (restart `mix phx.server` first: config/dev.exs changed)
yarn build                 # served by Phoenix at http://localhost:4000/app/NAME/
```

An Astro site keeps `"rephi": { "copyToPhoenix": false }`: it is meant for a static host, and the
generator prints how to build it for Phoenix instead. See `mix help rephi.gen.frontend`.

### Frontend Architecture

Each frontend app generated from the example template:
- Is served at `/app/APP_NAME` with automatic CSRF token injection
- Has its own development port configured
- Uses React Router with the correct basename
- Shares common components from `packages/shared-components`
- Builds to `priv/static/apps/APP_NAME` for Phoenix to serve

### Astro Example (static site for Cloudflare Pages)

[`apps/example-astro`](apps/example-astro/README.md) is the example app rebuilt with
[Astro](https://astro.build): prerendered pages, React islands for the interactive parts and
the same Phoenix integrations (JWT auth, RBAC guards, admin screens, channel notifications)
through `packages/shared-components`.

It is meant to be hosted apart from Phoenix, on a static host such as Cloudflare Pages:
- It is **not** copied to `priv/static/apps/` and has no `/app/...` route
- The API and socket URLs come from its own `PUBLIC_API_URL` / `PUBLIC_WS_URL` variables
- The backend must allow its origin (CORS and the WebSocket `check_origin`)

```bash
yarn shared:build
yarn example-astro:dev      # http://localhost:4321
yarn example-astro:build    # static site in apps/example-astro/dist
```

Its README covers the architecture, the environment variables and the deployment to
Cloudflare Pages.

### Building and Deploying Frontends

```bash
# Build all frontends (automatically copies to priv/static/apps/)
yarn build

# Build a specific app
yarn APP_NAME:build

# Clean all builds
yarn clean
```

`yarn build` ends with `scripts/copy-builds.js`, which copies every `apps/*/dist` to
`priv/static/apps/`. An app that is deployed elsewhere opts out in its `package.json`:

```json
"rephi": { "copyToPhoenix": false }
```

`node scripts/copy-builds.js --app APP_NAME` copies a single app explicitly, opted out or not.

## Architecture

### Backend Structure
```
lib/
├── rephi/              # Core business logic
│   ├── accounts/       # User management
│   └── authorization/  # RBAC system
├── rephi_web/          # Web layer
│   ├── controllers/    # API controllers
│   ├── auth/          # Authentication plugs
│   └── channels/      # WebSocket channels
```

### Frontend Structure
```
apps/                         # Frontend applications
├── example/                  # Example app (template, Vite + React SPA)
├── example-astro/            # Same app as a static Astro site (Cloudflare Pages)
└── [your-apps]/             # Generated apps

packages/                     # Shared packages
└── shared-components/       # Common React components, hooks, utilities

priv/static/apps/            # Built frontend apps served by Phoenix
├── example/
└── [your-apps]/
```

## API Documentation

Interactive API documentation is available via Swagger:

- **Swagger UI**: `http://localhost:4000/api/swagger`
- **Swagger JSON**: `http://localhost:4000/api/swagger/swagger.json`

To regenerate documentation after changes:
```bash
mix phx.swagger.generate
```

## Useful Commands

### Backend
```bash
# Run tests
mix test

# Everything CI checks: format, warnings as errors, unused deps, tests
mix precommit

# Format code
mix format

# Clean and rebuild
mix clean && mix compile

# Reset database
mix ecto.reset

# Generate Swagger documentation
mix phx.swagger.generate
```

### Frontend
```bash
# Build every workspace and copy the apps to priv/static/apps/
yarn build

# Lint and type-check every workspace
# (both resolve @rephi/shared-components from its dist/, so run `yarn shared:build` first)
yarn lint
yarn typecheck

# Preview the production build of one app
yarn workspace rephi-example preview

# Serve the Astro build with the local Cloudflare Pages emulator
yarn workspace rephi-example-astro pages:dev
```

## Technology Stack

### Backend (Phoenix/Elixir)
- **REST API** under `/api/*`
- **JWT Authentication** with Guardian
- **WebSockets** with Phoenix Channels
- **Database** PostgreSQL with Ecto
- **Documentation** automatic with Phoenix Swagger

### Frontend (React)
- **SPA Mode** without SSR (`apps/example`), or **static pages + React islands** with Astro
  (`apps/example-astro`)
- **Global State** with Zustand (persisted)
- **Forms** with React Hook Form + Zod
- **Styling** with Tailwind CSS v4
- **API Client** with Axios

## Authorization System

### JWT Authentication
1. Users register/authenticate at `/api/users/register` or `/api/users/login`
2. JWT is stored in Zustand and localStorage
3. Axios interceptor automatically adds `Authorization: Bearer {token}` header
4. Protected endpoints require valid authentication

### Role-Based Access Control (RBAC)

Rephi includes a complete role-based access control (RBAC) system with the following features:

#### Roles and Hierarchies
- **Hierarchical roles**: Roles can inherit permissions from other roles
- **Default roles**: 
  - `admin` → inherits from `manager`
  - `manager` → inherits from `user`
  - `user` → basic access

#### Granular Permissions
Permissions are organized by categories:

- **users:** - User management (`users:view`, `users:create`, `users:edit`, `users:delete`)
- **roles:** - Role management (`roles:view`, `roles:create`, `roles:edit`, `roles:delete`, `roles:assign`)
- **permissions:** - Permission management (`permissions:view`, `permissions:create`, etc.)
- **system:** - System configuration (`system:settings`, `system:logs`, `system:manage`)

#### Authorization Checks

**In Controllers:**
```elixir
# Protect individual actions
plug AuthorizationPlug, {:permission, "users:edit"}
plug AuthorizationPlug, {:role, "admin"}
plug AuthorizationPlug, {:any_permission, ["users:create", "users:edit"]}
plug AuthorizationPlug, {:all_permissions, ["users:edit", "system:manage"]}

# Manual checks
if can?(conn, "users:edit") do
  # User can edit users
end

if has_role?(conn, "admin") do
  # User has admin role
end
```

**In Context:**
```elixir
# Direct checks
Authorization.can?(user, "users:edit")
Authorization.has_role?(user, "admin")
Authorization.role_has_permission?(role, permission)

# Flexible checks
Authorization.can_by?(user: user, permission: "system:manage")
Authorization.can_by?(user: user, role: "admin")

# Get data
Authorization.get_user_roles(user)
Authorization.get_user_permissions(user)
Authorization.get_role_permissions(role)
```

#### Roles and Permissions API

**Role Management:**
```bash
GET    /api/roles              # List roles
POST   /api/roles              # Create role
GET    /api/roles/:id          # Get specific role
PUT    /api/roles/:id          # Update role
DELETE /api/roles/:id          # Delete role

# Role assignment to users
POST   /api/users/:user_id/roles/:role_id     # Assign role
DELETE /api/users/:user_id/roles/:role_id     # Remove role
```

**Permission Management:**
```bash
GET    /api/permissions         # List permissions
POST   /api/permissions         # Create permission
GET    /api/permissions/:id     # Get specific permission
PUT    /api/permissions/:id     # Update permission
DELETE /api/permissions/:id     # Delete permission

# Permission assignment to roles
POST   /api/roles/:role_id/permissions/:perm_id     # Assign permission
DELETE /api/roles/:role_id/permissions/:perm_id     # Remove permission
```

**Current User Information:**
```bash
GET /api/me  # Includes roles and permissions of authenticated user
```

#### Seed Data
When running `mix ecto.reset` or `mix run priv/repo/seeds.exs`, the following are automatically created:

- **3 roles** with hierarchy (admin → manager → user)
- **17 permissions** categorized by functionality
- **Administrator user** (`admin@admin.com` / `password123!!`) with admin role

#### JWT Integration
JWT tokens automatically include:
- User roles list (`"roles": ["admin", "manager"]`)
- Effective permissions list (`"permissions": ["users:view", "users:create", ...]`)

#### Authorization Helpers
Available in all controllers and views:
```elixir
can?(conn, "permission:slug")           # Has specific permission?
has_role?(conn, "role_slug")           # Has specific role?
can_any?(conn, ["perm1", "perm2"])     # Has any of these permissions?
can_all?(conn, ["perm1", "perm2"])     # Has all these permissions?
current_user_roles(conn)               # Current user roles
current_user_permissions(conn)         # Current user permissions
authorize(conn, permission: "users:edit") # Flexible verification
```

## WebSockets

WebSocket connection is established at `ws://localhost:4000/socket` with user-specific channels.

**✅ Security**: WebSocket connections validate the JWT token before allowing connection. Invalid or missing tokens are automatically rejected.

## Testing

```bash
mix test              # backend tests
mix test --cover      # with coverage (fails under the threshold in mix.exs)
mix precommit         # what CI runs for the backend
```

CI (`.github/workflows/ci.yml`) runs `mix precommit` against PostgreSQL, the installer's tests,
and `yarn install --immutable`, `yarn shared:build`, `yarn typecheck`, `yarn lint` and
`yarn build`.

## Deployment

The `Dockerfile` builds a release that includes the frontends (`priv/static/apps`) and
`swagger.json`; the apps call the API on the origin that serves them (`/api`, `/socket`).

```bash
docker build -t my_app .

# Every variable is described in .env.example; these four are required.
export DATABASE_URL=ecto://USER:PASS@HOST/DATABASE
export SECRET_KEY_BASE="$(mix phx.gen.secret)"
export GUARDIAN_SECRET_KEY="$(mix guardian.gen.secret)"
export PHX_HOST=api.example.com

docker run --rm -e DATABASE_URL -e SECRET_KEY_BASE -e GUARDIAN_SECRET_KEY -e PHX_HOST my_app bin/migrate
docker run --rm -e DATABASE_URL -e SECRET_KEY_BASE -e GUARDIAN_SECRET_KEY -e PHX_HOST \
  -e ADMIN_EMAIL=admin@example.com -e ADMIN_PASSWORD=... my_app bin/seed
docker run -p 4000:4000 -e DATABASE_URL -e SECRET_KEY_BASE -e GUARDIAN_SECRET_KEY -e PHX_HOST my_app
```

Without Docker, build the same release by hand:

```bash
# shared-components inlines the API and socket URLs when it is built
export VITE_SERVER_API_URL=/api VITE_WS_URL=/socket
yarn install --immutable && yarn shared:build && yarn build
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix phx.swagger.generate
MIX_ENV=prod mix release

_build/prod/rel/my_app/bin/migrate     # Ecto migrations (Rephi.Release.migrate/0)
_build/prod/rel/my_app/bin/seed        # roles, permissions, first admin (Rephi.Release.seed/0)
_build/prod/rel/my_app/bin/server      # starts the endpoint (PHX_SERVER=true)
```

`bin/seed` is idempotent: run it after the first migration (with `ADMIN_EMAIL` and
`ADMIN_PASSWORD`) and after upgrades that add default roles or permissions.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.