export { default as api } from "./api/api";
export { default as PhoenixSocket } from "./api/socket";
export type { SocketStatus } from "./api/socket";
export { AUTH_ENDPOINTS, changePassword, fetchMe, login, logout, register } from "./api/auth";
export {
  addRoleParent,
  fetchRoleChildren,
  fetchRoleParents,
  fetchUserPermissions,
  grantUserPermission,
  removeRoleParent,
  resetUserPassword,
  revokeUserPermission,
} from "./api/admin";
export { broadcastNotification, fetchDashboard, sendTestNotification } from "./api/notifications";
export {
  describePage,
  fetchAllPages,
  fetchPage,
  hasNextPage,
  hasPreviousPage,
  MAX_PAGE_SIZE,
} from "./api/pagination";
