// Components
export { PhoenixProvider, usePhoenix } from './components/PhoenixProvider';
export { AuthGuard } from './components/AuthGuard';
export { PermissionGuard } from './components/PermissionGuard';

// Hooks
export { useChannel } from './hooks';
export { usePermissions } from './hooks/usePermissions';

// Utils
export { 
  setRedirectPath,
  getRedirectPath,
  clearRedirectPath,
  filterRoutesByPermissions,
  createProtectedRoute
} from './utils/routes';
export type {
  RouteConfig
} from './utils/routes';

// Environment (build-time defaults) and runtime configuration
export { env } from './env';
export type { Env } from './env';
export { configureRephi, getRephiConfig } from './config';
export type { RephiConfig } from './config';

export {
  getCsrfToken,
  setCsrfHeader,
  api,
  PhoenixSocket
} from './controllers';

// Types
export type {
  ApiError,
  PaginatedResponse,
  ApiResponse,
  Role,
  Permission,
  User,
  AuthResponse,
  LoginCredentials,
  RegisterCredentials
} from './types';

// Stores
export { useAuthStore } from './stores';
