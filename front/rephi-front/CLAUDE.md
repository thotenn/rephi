# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

```bash
# Start development server
npm run dev

# Run linting
npm run lint

# Run TypeScript type checking
npm run typecheck

# Build for production
npm run build

# Start production server
npm start
```

## Architecture Overview

This is a Remix SPA (Single Page Application) that connects to a Phoenix/Elixir backend.

### Key Architectural Decisions

1. **SPA Mode**: Configured with `ssr: false` in vite.config.ts - runs as client-side only application
2. **Backend Communication**: 
   - REST API via Axios at `http://localhost:4000/api`
   - WebSocket via Phoenix channels at `ws://localhost:4000/socket`
3. **State Management**: Zustand with persistence for auth state
4. **Module Structure**: Feature-based organization in `/app/modules/`

### Module Architecture

**API Module** (`/app/modules/api/`):
- `api.ts`: Axios instance with auth token interceptor from Zustand store
- `socket.ts`: Phoenix WebSocket connection with token from localStorage

**Auth Module** (`/app/modules/auth/`):
- Zustand store persisted to localStorage
- Stores user object and token
- Methods: `setAuth(user, token)` and `logout()`

### Important Configuration

- **Path Aliases**: `~/` maps to `./app/` directory
- **Node Version**: Requires v20.0.0+
- **TypeScript**: Strict mode enabled
- **Styling**: Tailwind CSS with Inter font family

### Development Workflow

When making API calls, the auth token is automatically included via the Axios interceptor. The WebSocket connection also includes the token in its params.

The app expects a Phoenix backend running on port 4000 with:
- REST API endpoints at `/api/*`
- WebSocket endpoint at `/socket`