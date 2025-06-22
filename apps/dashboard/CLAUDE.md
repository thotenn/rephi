# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Run linting
npm run lint

# Run TypeScript type checking
npm run typecheck

# Build for production
npm run build

# Preview production build
npm run preview
```

## Architecture Overview

This is a React Router v7 SPA (Single Page Application) that connects to a Phoenix/Elixir backend.

### Key Architectural Decisions

1. **React Router v7**: Latest version of React Router with modern routing patterns
2. **React 19**: Latest version of React with enhanced features
3. **SPA Mode**: Client-side only application with no server-side rendering
4. **Backend Communication**: 
   - REST API via Axios at `http://localhost:4000/api`
   - WebSocket via Phoenix channels at `ws://localhost:4000/socket`
5. **State Management**: Zustand with persistence for auth state
6. **Module Structure**: Feature-based organization in `/src/modules/`

### Module Architecture

**API Module** (`/src/modules/api/`):
- `api.ts`: Axios instance with auth token interceptor from Zustand store
- `socket.ts`: Phoenix WebSocket connection with token from localStorage

**Auth Module** (`/src/modules/auth/`):
- Zustand store persisted to localStorage
- Stores user object and token
- Methods: `setAuth(user, token)` and `logout()`

### Important Configuration

- **Path Aliases**: `~/` maps to `./src/` directory
- **Node Version**: Requires v20.0.0+
- **TypeScript**: Strict mode enabled with React 19 types
- **Styling**: Tailwind CSS v4 with Inter font family
- **Bundler**: Vite for fast development and optimized builds

### Development Workflow

When making API calls, the auth token is automatically included via the Axios interceptor. The WebSocket connection also includes the token in its params.

The app expects a Phoenix backend running on port 4000 with:
- REST API endpoints at `/api/*`
- WebSocket endpoint at `/socket`

### Environment Variables

Copy `.env.example` to `.env` and configure:
- `VITE_API_URL`: Backend API URL (default: http://localhost:4000/api)
- `VITE_SOCKET_URL`: WebSocket URL (default: ws://localhost:4000/socket)

### Route Structure

- `/` - Welcome/landing page
- `/login` - User authentication
- `/register` - User registration
- `/home` - Dashboard home (protected)
- `/pages/profile` - User profile (protected)
- `/pages/dashboard` - Analytics dashboard (protected)

All protected routes require authentication and will redirect to login if not authenticated.