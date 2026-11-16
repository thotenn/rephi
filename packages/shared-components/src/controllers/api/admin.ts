import type {
  ApiResponse,
  PasswordReset,
  RoleLink,
  RoleParentAssignment,
  UserPermissionAssignment,
  UserPermissions,
} from "../../types";
import api from "./api";

const unwrap = <T>({ data }: { data: ApiResponse<T> }): T => data.data;

export function fetchRoleParents(roleId: number): Promise<RoleLink[]> {
  return api.get<ApiResponse<RoleLink[]>>(`/roles/${roleId}/parents`).then(unwrap);
}

export function fetchRoleChildren(roleId: number): Promise<RoleLink[]> {
  return api.get<ApiResponse<RoleLink[]>>(`/roles/${roleId}/children`).then(unwrap);
}

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

export async function removeRoleParent(roleId: number, parentId: number): Promise<void> {
  await api.delete(`/roles/${roleId}/parents/${parentId}`);
}

export function fetchUserPermissions(userId: number): Promise<UserPermissions> {
  return api.get<ApiResponse<UserPermissions>>(`/users/${userId}/permissions`).then(unwrap);
}

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

export async function revokeUserPermission(userId: number, permissionId: number): Promise<void> {
  await api.delete(`/users/${userId}/permissions/${permissionId}`);
}

export function resetUserPassword(userId: number): Promise<PasswordReset> {
  return api.post<ApiResponse<PasswordReset>>(`/users/${userId}/password`).then(unwrap);
}
