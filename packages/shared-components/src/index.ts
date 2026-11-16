// Configuration (call `configureRephi` once, before the first request)
export { configureRephi, getRephiConfig } from './config';
export type { RephiConfig } from './config';

// HTTP client, auth calls, administration calls and pagination
export {
  addRoleParent,
  api,
  AUTH_ENDPOINTS,
  changePassword,
  describePage,
  fetchAllPages,
  fetchMe,
  fetchPage,
  fetchRoleChildren,
  fetchRoleParents,
  fetchUserPermissions,
  grantUserPermission,
  hasNextPage,
  hasPreviousPage,
  login,
  logout,
  MAX_PAGE_SIZE,
  PhoenixSocket,
  register,
  removeRoleParent,
  resetUserPassword,
  revokeUserPermission
} from './controllers';
export type { SocketStatus } from './controllers';

// Errors
export {
  ApiError,
  describeError,
  fieldErrorsToMessage,
  getErrorMessage,
  getFieldErrors,
  humanizeField,
  isApiError
} from './errors';
export type { ErrorInfo } from './errors';

// Session
export { endSession, onSessionEnd, startSession } from './session';
export { AUTH_STORAGE_KEY, useAuthStore } from './stores';

// Authorization helpers (UI only)
export { userCan, userCanAll, userCanAny, userHasRole } from './permissions';

// Realtime
export { LOBBY_TOPIC, NOTIFICATION_EVENT, userTopic } from './realtime';

// Components
export { AuthGuard } from './components/AuthGuard';
export { PermissionGuard } from './components/PermissionGuard';

// Hooks
export { useChannel, useChannelEvent, usePermissions, usePhoenixSocket } from './hooks';
export type { UseChannelOptions, UseChannelResult } from './hooks';

// Utils
export {
  clearRedirectPath,
  createProtectedRoute,
  filterRoutesByPermissions,
  getRedirectPath,
  setRedirectPath
} from './utils/routes';
export type { RouteAccess, RouteConfig } from './utils/routes';

// Types
export type {
  ApiErrorBody,
  ApiResponse,
  AuthSession,
  ChangePasswordParams,
  DirectUserPermission,
  EffectiveUserPermission,
  FieldErrors,
  LoginCredentials,
  ManagedUser,
  PageMeta,
  PageParams,
  PaginatedResponse,
  PasswordReset,
  Permission,
  RegisterCredentials,
  RephiNotification,
  Role,
  RoleLink,
  RoleParentAssignment,
  SessionEndReason,
  User,
  UserPermissionAssignment,
  UserPermissions
} from './types';
