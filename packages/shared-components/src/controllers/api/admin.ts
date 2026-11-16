import type {
  ApiResponse,
  PasswordReset,
  RoleLink,
  RoleParentAssignment,
  UserPermissionAssignment,
  UserPermissions,
} from "../../types";
import api from "./api";

/**
 * Administration calls that have a contract of their own: the role hierarchy,
 * the permissions granted to users directly and the password reset. Every
 * function rejects with an `ApiError`; the statuses each one can answer are
 * listed with it (401 and network errors apply to all).
 */

const unwrap = <T>({ data }: { data: ApiResponse<T> }): T => data.data;

// --- Role hierarchy ----------------------------------------------------------

/** The roles `roleId` inherits from directly, by slug (`roles:view`; 403, 404). */
export function fetchRoleParents(roleId: number): Promise<RoleLink[]> {
  return api.get<ApiResponse<RoleLink[]>>(`/roles/${roleId}/parents`).then(unwrap);
}

/** The roles that inherit from `roleId` directly, by slug (`roles:view`; 403, 404). */
export function fetchRoleChildren(roleId: number): Promise<RoleLink[]> {
  return api.get<ApiResponse<RoleLink[]>>(`/roles/${roleId}/children`).then(unwrap);
}

/**
 * Makes `roleId` inherit every permission of `parentId` (`roles:edit`, and
 * holding both roles unless admin). 403 not allowed, 404 unknown role, 409 the
 * role would inherit from itself or already inherits from it, 422 invalid notes.
 */
export function addRoleParent(
  roleId: number,
  parentId: number,
  notes?: string
): Promise<RoleParentAssignment> {
  const body = notes === undefined ? undefined : { notes };
  return api
    .post<ApiResponse<RoleParentAssignment>>(`/roles/${roleId}/parents/${parentId}`, body)
    .then(unwrap);
}

/**
 * `roleId` stops inheriting from `parentId` (`roles:edit`, and holding both
 * roles unless admin). 403, 404 (also when not linked), 409 a link of the
 * default hierarchy or the last admins' only path to the admin role.
 */
export async function removeRoleParent(roleId: number, parentId: number): Promise<void> {
  await api.delete(`/roles/${roleId}/parents/${parentId}`);
}

// --- Permissions granted to users directly ----------------------------------

/**
 * The permissions granted to the user directly, and everything it may do
 * with the source of each (`users:view`; 403, 404).
 */
export function fetchUserPermissions(userId: number): Promise<UserPermissions> {
  return api.get<ApiResponse<UserPermissions>>(`/users/${userId}/permissions`).then(unwrap);
}

/**
 * Grants a permission to the user directly (`permissions:assign`, and holding
 * the permission unless admin). 403, 404, 409 already granted, 422 invalid notes.
 */
export function grantUserPermission(
  userId: number,
  permissionId: number,
  notes?: string
): Promise<UserPermissionAssignment> {
  const body = notes === undefined ? undefined : { notes };
  return api
    .post<ApiResponse<UserPermissionAssignment>>(`/users/${userId}/permissions/${permissionId}`, body)
    .then(unwrap);
}

/**
 * Revokes a permission granted to the user directly (`permissions:assign`, and
 * holding the permission unless admin). 403, 404 (also when the user does not
 * hold it), 409 the user only holds it through a role.
 */
export async function revokeUserPermission(userId: number, permissionId: number): Promise<void> {
  await api.delete(`/users/${userId}/permissions/${permissionId}`);
}

// --- Password reset ----------------------------------------------------------

/**
 * Gives another user a random temporary password, returned once
 * (`users:reset_password`, and holding every role of the user unless admin).
 * Every session of that user ends; it must choose a new password after
 * signing in (`must_change_password`). 403, 404, 409 for your own account
 * (use `changePassword`).
 */
export function resetUserPassword(userId: number): Promise<PasswordReset> {
  return api.post<ApiResponse<PasswordReset>>(`/users/${userId}/password`).then(unwrap);
}
