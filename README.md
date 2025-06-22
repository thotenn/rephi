# Rephi

A production-ready Phoenix boilerplate with JWT authentication, RBAC authorization, WebSocket support, and multi-frontend architecture.

## 🚀 Quick Start

### Create a new project using Rephi

1. **Install the Rephi project generator**
   ```bash
   mix archive.install hex rephi_new
   ```

2. **Create your new project**
   ```bash
   mix rephi.new my_app
   cd my_app
   ```

3. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your database credentials and configuration
   ```

4. **Setup and run**
   ```bash
   mix setup
   mix phx.server
   ```

   Visit [`localhost:4000`](http://localhost:4000) from your browser.

### Prerequisites

- **Elixir** 1.14 or higher
- **Erlang** 24 or higher
- **PostgreSQL** 12 or higher
- **Node.js** 18 or higher
- **npm** or **yarn**

## Features

- **🔐 JWT Authentication**: Secure token-based authentication system
- **👮 RBAC Authorization**: Complete Role-Based Access Control with hierarchical permissions
- **🔌 WebSocket Support**: Real-time communication via Phoenix Channels
- **⚛️ Multi-Frontend Architecture**: Support for multiple React SPAs (dashboard, admin, e-commerce, landing)
- **📚 API Documentation**: Auto-generated Swagger/OpenAPI documentation
- **🏗️ Production Ready**: Configured for scalability and best practices
- **🛡️ CSRF Protection**: Built-in CSRF token injection for SPAs

### Manual Setup (for development)

1. **Clone the repository**
   ```bash
   git clone https://github.com/thotenn/rephi.git
   cd rephi
   ```

2. **Install dependencies**
   ```bash
   mix deps.get
   ```

3. **Configure database**
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

   Or use the complete setup command:
   ```bash
   mix setup
   ```

4. **Start Phoenix server**
   ```bash
   mix phx.server
   ```
   
   Or with interactive shell:
   ```bash
   iex -S mix phx.server
   ```

   Backend will be available at `http://localhost:4000`

## Frontend Development

Each frontend app is a standalone React application:

```bash
cd apps/dashboard
npm install
npm run dev
```

### Building Frontends

```bash
# Build all frontends
mix frontends.build

# Clean frontend builds
mix frontends.clean
```

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
apps/
├── shared/            # Shared React components
├── dashboard/         # Dashboard SPA
├── admin/            # Admin panel SPA
├── ecommerce/        # E-commerce SPA
└── landing/          # Landing page SPA
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
# Build for production
npm run build

# Run linter
npm run lint

# Check TypeScript types
npm run typecheck

# Start production server
npm start
```

## Technology Stack

### Backend (Phoenix/Elixir)
- **REST API** under `/api/*`
- **JWT Authentication** with Guardian
- **WebSockets** with Phoenix Channels
- **Database** PostgreSQL with Ecto
- **Documentation** automatic with Phoenix Swagger

### Frontend (React)
- **SPA Mode** without SSR
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
# Run backend tests
mix test

# Run with coverage
mix test --cover
```

## Deployment

### Building for Production

```bash
# Backend
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy

# Frontends
mix frontends.build
```

### Docker Support

```bash
docker build -t rephi .
docker run -p 4000:4000 rephi
```

## Publishing to Hex.pm

1. Update the version in `mix.exs`
2. Update `CHANGELOG.md` with release notes
3. Ensure tests pass: `mix test`
4. Create git tag: `git tag -a v0.1.0 -m "Release v0.1.0"`
5. Publish: `mix hex.publish`

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.