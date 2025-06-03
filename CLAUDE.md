# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rephi is a Phoenix/Elixir backend with a Remix React frontend, featuring JWT authentication, RBAC (Role-Based Access Control) authorization system, and real-time WebSocket communication.

## Environment Setup

1. **Copy environment file**:
   ```bash
   cp .env.example .env
   ```

2. **Update `.env` with your configuration**:
   - Database credentials
   - Secret keys (generate with `mix phx.gen.secret`)
   - Port and host settings
   - Other environment-specific values

3. **Environment variables are loaded automatically** in dev/test environments from the `.env` file.

## Common Development Commands

### Backend (Phoenix/Elixir)
```bash
# Setup
mix setup              # Install deps and setup database
mix deps.get          # Install dependencies only
mix ecto.create       # Create database
mix ecto.migrate      # Run migrations
mix ecto.reset        # Drop and recreate database with migrations

# Development
mix phx.server        # Start Phoenix server (port 4000)
iex -S mix phx.server # Start with interactive shell

# Testing & Code Quality
mix test              # Run all tests
mix format            # Format Elixir code

# API Documentation
mix phx.swagger.generate  # Generate Swagger JSON documentation
```

### Frontend (Remix/React)
```bash
# Navigate to frontend directory first
cd front/rephi-front

# Development
npm run dev           # Start development server
npm run build         # Build for production
npm start             # Start production server

# Code Quality
npm run lint          # Run ESLint
npm run typecheck     # Run TypeScript type checking
```

## Architecture Overview

### Authentication & Authorization Flow
1. **Frontend → Backend**: Login/register sends credentials to `/api/users/{login|register}`
2. **Token Storage**: JWT stored in both Zustand (persisted) and localStorage
3. **JWT Enhancement**: Tokens include user roles and permissions for client-side authorization
4. **API Requests**: Axios interceptor adds `Authorization: Bearer {token}` header automatically
5. **Authorization**: Server-side plugs verify permissions before allowing access to protected endpoints
6. **WebSocket**: Token passed as connection param but **NOT currently validated** (security issue)

### RBAC Authorization System
- **Hierarchical Roles**: `admin` → `manager` → `user` with inheritance
- **Granular Permissions**: Categorized by domain (`users:*`, `roles:*`, `permissions:*`, `system:*`)
- **Flexible Checks**: Support for single permission, multiple permissions (any/all), role-based checks
- **Database Schema**: 6 tables for complete RBAC implementation
- **API Endpoints**: Full CRUD for roles and permissions with assignment capabilities

### Key Architectural Decisions
- **Backend API**: All API routes under `/api/*` with JSON responses
- **Frontend SPA**: Remix in SPA mode (no SSR) with client-side routing
- **State Management**: Zustand with localStorage persistence for auth state
- **Authorization**: Context-based with plugs for controller protection
- **Real-time**: Phoenix Channels for WebSocket communication (user-specific channels)
- **Forms**: React Hook Form + Zod for validation
- **Styling**: Tailwind CSS v4 with custom configuration

### Important Security Note
WebSocket connections in `UserSocket.connect/3` currently accept all connections without validating the token parameter. This needs to be fixed to properly authenticate WebSocket connections.

## Testing Approach
- **Backend**: ExUnit tests in `/test` directory, run with `mix test`
- **Frontend**: No test framework currently configured
- **Database**: Test database automatically created/migrated when running tests

## Development Workflow
1. Start PostgreSQL
2. Run backend: `mix phx.server` (port 4000)
3. In another terminal, run frontend: `cd front/rephi-front && npm run dev`
4. Backend API available at `http://localhost:4000/api`
5. WebSocket connection at `ws://localhost:4000/socket`
6. Swagger UI available at `http://localhost:4000/api/swagger`
7. Swagger JSON available at `http://localhost:4000/api/swagger/swagger.json`

## API Documentation with Swagger

### Overview
The project uses Phoenix Swagger to automatically generate API documentation. All endpoints are documented with request/response schemas, examples, and security requirements.

### Adding Documentation to New Endpoints

When creating new endpoints, follow these steps:

1. **Import required modules** in your controller:
```elixir
use PhoenixSwagger
alias PhoenixSwagger.Schema
```

2. **Document the endpoint** using `swagger_path` before the function:
```elixir
swagger_path :action_name do
  get("/api/path")
  summary("Brief description")
  description("Detailed description")
  produces("application/json")
  
  # For authenticated endpoints
  security([%{Bearer: []}])
  
  # Define parameters
  parameters do
    param_name(:query, :string, "Parameter description", required: true)
  end
  
  # Define responses
  response(200, "Success", Schema.ref(:ResponseSchema))
  response(401, "Unauthorized")
end
```

3. **Define schemas** in `swagger_definitions/0`:
```elixir
def swagger_definitions do
  %{
    ResponseSchema: %{
      type: :object,
      title: "Response Title",
      description: "Response description",
      properties: %{
        field: %{type: :string, description: "Field description"}
      },
      required: [:field],
      example: %{
        field: "example value"
      }
    }
  }
end
```

4. **Generate documentation** after adding/modifying endpoints:
```bash
mix phx.swagger.generate
```

## Testing Requirements for New Endpoints

**IMPORTANT**: For every new endpoint created, you MUST also create corresponding test files in the `/test` directory. This ensures code quality and prevents regressions.

### Creating Tests for New Endpoints

1. **Create a test file** in `test/rephi_web/controllers/`:
```elixir
defmodule RephiWeb.YourControllerTest do
  use RephiWeb.ConnCase
  
  # Import auth helpers if needed
  import Rephi.AuthTestHelpers
  
  describe "your_action/2" do
    test "successful case", %{conn: conn} do
      # Test implementation
    end
    
    test "error case", %{conn: conn} do
      # Test implementation
    end
  end
end
```

2. **Test all scenarios**:
   - ✅ Success cases with valid data
   - ❌ Error cases with invalid data
   - 🔐 Authentication/authorization scenarios
   - 🚫 Missing or malformed parameters
   - 📝 Validation errors

3. **Use test helpers** from `test/support/auth_test_helpers.ex`:
   - `create_user/1` - Create test users
   - `create_user_with_token/1` - Create authenticated users
   - `authenticate_conn/2` - Add auth headers
   - `valid_user_attrs/1` - Generate valid test data

4. **Run tests** to ensure they pass:
```bash
mix test                           # Run all tests
mix test test/path/to/test.exs    # Run specific test file
```

### Test File Structure Example

```elixir
# For a new endpoint POST /api/items
# Create: test/rephi_web/controllers/item_controller_test.exs

defmodule RephiWeb.ItemControllerTest do
  use RephiWeb.ConnCase

  @valid_attrs %{"name" => "Test Item", "description" => "Test Description"}
  @invalid_attrs %{"name" => nil}

  describe "create/2" do
    setup %{conn: conn} do
      # Authenticate if endpoint requires it
      conn = authenticate_user(conn)
      {:ok, conn: conn}
    end

    test "creates item with valid data", %{conn: conn} do
      conn = post(conn, ~p"/api/items", @valid_attrs)
      assert %{"id" => id, "name" => "Test Item"} = json_response(conn, 201)
    end

    test "returns errors with invalid data", %{conn: conn} do
      conn = post(conn, ~p"/api/items", @invalid_attrs)
      assert %{"errors" => errors} = json_response(conn, 422)
    end
  end
end
```

### Integration Tests

For complex flows, create integration tests in `test/rephi_web/integration/`:
- Test complete user journeys
- Verify multiple endpoints work together
- Ensure data consistency across operations

### Current API Documentation

- **Authentication Endpoints** (`/api/users/*`): User registration, login, and profile
- **Authorization Endpoints** (`/api/roles/*`, `/api/permissions/*`): Full RBAC management
- **Role Assignment** (`/api/users/:id/roles/*`): Assign/remove roles from users
- **Permission Assignment** (`/api/roles/:id/permissions/*`): Assign/remove permissions from roles
- All endpoints return JSON responses
- Authentication uses JWT tokens in Authorization header
- Authorization uses permission-based access control
- See Swagger UI for interactive documentation and testing

## Authorization System Implementation

### Context Module: `Rephi.Authorization`
Main functions for role and permission management:

**Role Management:**
- `list_roles/0`, `get_role/1`, `get_role_by_slug/1`
- `create_role/1`, `update_role/2`, `delete_role/1`
- `assign_role_to_user/3`, `remove_role_from_user/2`

**Permission Management:**
- `list_permissions/0`, `get_permission/1`, `get_permission_by_slug/1`
- `create_permission/1`, `update_permission/2`, `delete_permission/1`
- `assign_permission_to_role/3`, `remove_permission_from_role/2`

**Authorization Checks:**
- `can?/2` - Check if user has specific permission
- `has_role?/2` - Check if user has specific role
- `get_user_roles/1`, `get_user_permissions/1`, `get_role_permissions/1`
- `can_by?/1` - Flexible authorization with options

### Authorization Plugs
Located in `RephiWeb.Auth.AuthorizationPlug`:

**Usage in Controllers:**
```elixir
plug AuthorizationPlug, {:permission, "users:edit"}
plug AuthorizationPlug, {:role, "admin"}
plug AuthorizationPlug, {:any_permission, ["users:create", "users:edit"]}
plug AuthorizationPlug, {:all_permissions, ["users:edit", "system:manage"]}
```

### Authorization Helpers
Available in all controllers via `RephiWeb.Auth.AuthorizationHelpers`:
- `can?/2`, `has_role?/2`, `can_any?/2`, `can_all?/2`
- `current_user_roles/1`, `current_user_permissions/1`
- `authorize/2` - Flexible authorization function

### Database Schema
Six tables support the RBAC system:
1. `roles` - Role definitions with hierarchy support
2. `permissions` - Permission definitions with hierarchy support  
3. `user_roles` - User-role assignments
4. `user_permissions` - Direct user-permission assignments
5. `role_permissions` - Role-permission assignments
6. `role_roles` - Role hierarchy (parent-child relationships)

### Seed Data
Default roles and permissions created automatically:
- **Roles**: admin (inherits manager), manager (inherits user), user
- **Permissions**: 17 permissions across users, roles, permissions, and system domains
- **Admin User**: admin@admin.com / password123!! with admin role

### Testing Authorization
When testing endpoints with authorization:
1. Use `RephiWeb.AuthTestHelpers` for auth setup
2. Test both authorized and unauthorized scenarios
3. Test different permission/role combinations
4. Verify proper HTTP status codes (401 Unauthorized, 403 Forbidden)