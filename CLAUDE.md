# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rephi is a Phoenix/Elixir backend with a Remix React frontend, featuring JWT authentication and real-time WebSocket communication.

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

### Current API Documentation

- **Authentication Endpoints** (`/api/users/*`): User registration, login, and profile
- All endpoints return JSON responses
- Authentication uses JWT tokens in Authorization header
- See Swagger UI for interactive documentation and testing