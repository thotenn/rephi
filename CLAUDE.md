# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rephi is a Phoenix/Elixir backend with multi-frontend React SPAs (Yarn workspaces), featuring JWT authentication, RBAC authorization, and real-time WebSocket communication.

## Environment Setup

```bash
# Quick setup (recommended)
./setup.sh

# Or manually:
cp .env.example .env  # Configure database, secrets (use `mix phx.gen.secret`), ports
```

Environment variables are loaded automatically in dev/test from `.env`.

## Common Commands

### Backend (Phoenix/Elixir)
```bash
mix setup                    # Full setup: deps, database, seed data
mix phx.server               # Start server (port 4000)
iex -S mix phx.server        # Start with interactive shell
mix test                     # Run all tests
mix test path/to/test.exs    # Run specific test file
mix test path/to/test.exs:42 # Run specific test at line
mix format                   # Format code
mix phx.swagger.generate     # Regenerate Swagger docs
mix docs                     # Generate ExDoc documentation
mix ecto.reset               # Drop and recreate database with seeds
```

### Frontend (Yarn Workspaces)
```bash
yarn install                 # Install all workspace dependencies
yarn shared:build            # Build shared-components (required first!)
yarn example:dev             # Start example app dev server
yarn build                   # Build all apps (copies to priv/static/apps/)
yarn lint                    # Lint all apps
yarn typecheck               # TypeScript check all apps
mix rephi.gen.frontend NAME  # Generate new frontend app
```

> **Important:** Run `yarn shared:build` before `yarn example:dev` - apps depend on the compiled shared-components package.

## Architecture

### Backend Structure
```
lib/rephi/                   # Core business logic
├── accounts/                # User management (Accounts context)
└── authorization/           # RBAC system (Authorization context)
    ├── role.ex, permission.ex
    ├── user_role.ex, user_permission.ex
    └── role_permission.ex, role_role.ex

lib/rephi_web/               # Web layer
├── auth/                    # Authentication (Guardian, Pipeline, AuthorizationPlug)
├── controllers/             # API controllers
├── channels/                # WebSocket (UserSocket, UserChannel)
└── plugs/                   # Custom plugs (FrontendAppPlug)
```

### Frontend Structure
```
apps/                        # Frontend applications (Vite + React)
├── example/                 # Template app
└── [generated-apps]/

packages/
└── shared-components/       # Common React components, hooks, utilities

priv/static/apps/            # Built frontends served by Phoenix
```

### Key Files
- `lib/rephi_web/router.ex` - All API routes under `/api/*`, frontend routes at `/app/*`
- `lib/rephi/authorization.ex` - Main RBAC context with `can?/2`, `has_role?/2`
- `lib/rephi_web/auth/authorization_plug.ex` - Controller authorization
- `priv/repo/seeds.exs` - Default roles, permissions, admin user

### Authentication Flow
1. Login/register: `POST /api/users/{login|register}` returns JWT
2. JWT includes user roles and permissions for client-side authorization
3. Frontend stores token in Zustand (persisted) + localStorage
4. Axios interceptor adds `Authorization: Bearer {token}` header
5. Protected routes use `RephiWeb.Auth.Pipeline` + `Guardian.Plug.EnsureAuthenticated`

### Authorization Usage
```elixir
# In controllers - use plugs
plug AuthorizationPlug, {:permission, "users:edit"}
plug AuthorizationPlug, {:role, "admin"}
plug AuthorizationPlug, {:any_permission, ["users:create", "users:edit"]}

# In code - use helpers
if can?(conn, "users:edit"), do: # ...
if Authorization.has_role?(user, "admin"), do: # ...
```

### Default Seed Data
- **Roles**: admin (inherits manager), manager (inherits user), user
- **Permissions**: 17 permissions across `users:*`, `roles:*`, `permissions:*`, `system:*`
- **Admin**: admin@admin.com / password123!!

## API Documentation

- Swagger UI: `http://localhost:4000/api/swagger`
- Swagger JSON: `http://localhost:4000/api/swagger/swagger.json`

When adding endpoints, use `swagger_path` macro and define schemas in `swagger_definitions/0`, then run `mix phx.swagger.generate`.

## Testing

Tests use ExUnit in `/test`. For authenticated endpoints, use helpers from `test/support/auth_test_helpers.ex`:

```elixir
import Rephi.AuthTestHelpers

# In tests
{user, token} = create_user_with_token()
conn = authenticate_conn(conn, token)
# or
conn = authenticate_user(conn)  # creates user + authenticates in one step
```

## Development Workflow

1. Start PostgreSQL
2. Run backend: `mix phx.server` (port 4000)
3. Run frontend: `yarn example:dev` (or other app)
4. API: `http://localhost:4000/api`
5. WebSocket: `ws://localhost:4000/socket`
6. Frontend apps: `http://localhost:4000/app/{app_name}`
