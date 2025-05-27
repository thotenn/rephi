# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rephi is a Phoenix/Elixir backend with a Remix React frontend, featuring JWT authentication and real-time WebSocket communication.

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

### Authentication Flow
1. **Frontend → Backend**: Login/register sends credentials to `/api/users/{login|register}`
2. **Token Storage**: JWT stored in both Zustand (persisted) and localStorage
3. **API Requests**: Axios interceptor adds `Authorization: Bearer {token}` header automatically
4. **WebSocket**: Token passed as connection param but **NOT currently validated** (security issue)

### Key Architectural Decisions
- **Backend API**: All API routes under `/api/*` with JSON responses
- **Frontend SPA**: Remix in SPA mode (no SSR) with client-side routing
- **State Management**: Zustand with localStorage persistence for auth state
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
- All endpoints return JSON responses
- Authentication uses JWT tokens in Authorization header
- See Swagger UI for interactive documentation and testing