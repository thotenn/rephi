// Components
export { PhoenixProvider, usePhoenix } from './components/PhoenixProvider';
export { AuthGuard } from './components/AuthGuard';
export { PermissionGuard } from './components/PermissionGuard';

// Hooks
export { useChannel } from './hooks/useChannel';
export { usePermissions } from './hooks/usePermissions';

// Utils
export { filterRoutesByPermissions, createProtectedRoute } from './utils/routes';
export type { RouteConfig } from './utils/routes';