export { configureRephi, getRephiConfig } from './config';
export type { RephiConfig } from './config';

export {
  addRoleParent,
  api,
  AUTH_ENDPOINTS,
  broadcastNotification,
  changePassword,
  describePage,
  fetchAllPages,
  fetchDashboard,
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
  revokeUserPermission,
  sendTestNotification
} from './controllers';
export type { SocketStatus } from './controllers';

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

export { endSession, onSessionEnd, startSession } from './session';
export { AUTH_STORAGE_KEY, useAuthStore } from './stores';

export { userCan, userCanAll, userCanAny, userHasRole } from './permissions';

export { LOBBY_TOPIC, NOTIFICATION_EVENT, userTopic } from './realtime';
export { presenceCounts } from './utils/presence';

// Components
export { AuthGuard } from './components/AuthGuard';
export { PermissionGuard } from './components/PermissionGuard';

// Hooks
export { useChannel, useChannelEvent, usePermissions, usePhoenixSocket } from './hooks';
export type { PresenceEntry, UseChannelOptions, UseChannelResult } from './hooks';

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
  DashboardStats,
  DirectUserPermission,
  EffectiveUserPermission,
  FieldErrors,
  LoginCredentials,
  ManagedUser,
  OnlineCounts,
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
