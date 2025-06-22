# @rephi/shared-components

Shared components library for Rephi multi-frontend applications.

## Installation

This package is part of the Rephi monorepo and is automatically available to apps within the workspace.

## Components

### PhoenixProvider
Provider component for Phoenix WebSocket connections.

```tsx
import { PhoenixProvider } from '@rephi/shared-components';

<PhoenixProvider 
  socketUrl="ws://localhost:4000/socket"
  autoConnect={true}
  token={authToken}
>
  <App />
</PhoenixProvider>
```

### AuthGuard
Component for protecting routes that require authentication.

```tsx
import { AuthGuard } from '@rephi/shared-components';

<AuthGuard 
  isAuthenticated={!!user}
  fallback={<LoginPage />}
>
  <ProtectedContent />
</AuthGuard>
```

### PermissionGuard
Component for protecting content based on permissions.

```tsx
import { PermissionGuard } from '@rephi/shared-components';

<PermissionGuard
  permissions={['users:edit']}
  userPermissions={currentUserPermissions}
  fallback={<AccessDenied />}
>
  <AdminPanel />
</PermissionGuard>
```

## Hooks

### useChannel
Hook for managing Phoenix channels.

```tsx
import { useChannel } from '@rephi/shared-components';

const { channel, joined, push, on } = useChannel('user:123', {
  onJoin: () => console.log('Joined channel'),
  onError: (error) => console.error('Channel error:', error)
});
```

### usePermissions
Hook for managing user permissions and roles.

```tsx
import { usePermissions } from '@rephi/shared-components';

const { hasPermission, hasRole } = usePermissions({
  roles: ['admin'],
  permissions: ['users:edit', 'users:delete']
});
```

## Utils

### Route Utilities
Helper functions for managing protected routes.

```tsx
import { filterRoutesByPermissions, createProtectedRoute } from '@rephi/shared-components';

const protectedRoute = createProtectedRoute('/admin', {
  permissions: ['admin:access'],
  roles: ['admin']
});
```

## Development

```bash
# Build the library
yarn shared:build

# Watch mode for development
yarn workspace @rephi/shared-components dev
```