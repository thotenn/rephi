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