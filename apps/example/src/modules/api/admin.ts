import {
  addRoleParent,
  api,
  fetchAllPages,
  fetchPage,
  fetchRoleChildren,
  fetchRoleParents,
  fetchUserPermissions,
  grantUserPermission,
  removeRoleParent,
  resetUserPassword,
  revokeUserPermission,
  type ApiResponse,
  type PageParams,
  type PaginatedResponse,
} from "@rephi/shared-components";
import type {
  Permission,
  PermissionFormData,
  Role,
  RoleDetail,
  RoleFormData,
  UserRole,
  UserWithGrants,
} from "~/types/admin.types";

export const ADMIN_PAGE_SIZE = 20;

const unwrap = <T>(res: { data: ApiResponse<T> }) => res.data.data;

export const rolesApi = {
  list: (params: PageParams): Promise<PaginatedResponse<Role>> => fetchPage<Role>("/roles", params),
  all: (): Promise<Role[]> => fetchAllPages<Role>("/roles"),
  get: (id: number): Promise<RoleDetail> => api.get(`/roles/${id}`).then(unwrap<RoleDetail>),
  create: (data: RoleFormData): Promise<RoleDetail> =>
    api.post("/roles", { role: data }).then(unwrap<RoleDetail>),
  update: (id: number, data: Partial<RoleFormData>): Promise<RoleDetail> =>
    api.put(`/roles/${id}`, { role: data }).then(unwrap<RoleDetail>),
  delete: (id: number): Promise<void> => api.delete(`/roles/${id}`).then(() => undefined),
  assignPermission: (roleId: number, permissionId: number): Promise<void> =>
    api.post(`/roles/${roleId}/permissions/${permissionId}`).then(() => undefined),
  removePermission: (roleId: number, permissionId: number): Promise<void> =>
    api.delete(`/roles/${roleId}/permissions/${permissionId}`).then(() => undefined),
  parents: fetchRoleParents,
  children: fetchRoleChildren,
  addParent: (roleId: number, parentId: number) => addRoleParent(roleId, parentId),
  removeParent: removeRoleParent,
};

export const permissionsApi = {
  list: (params: PageParams): Promise<PaginatedResponse<Permission>> =>
    fetchPage<Permission>("/permissions", params),
  all: (): Promise<Permission[]> => fetchAllPages<Permission>("/permissions"),
  create: (data: PermissionFormData): Promise<Permission> =>
    api.post("/permissions", { permission: data }).then(unwrap<Permission>),
  update: (id: number, data: Partial<PermissionFormData>): Promise<Permission> =>
    api.put(`/permissions/${id}`, { permission: data }).then(unwrap<Permission>),
  delete: (id: number): Promise<void> => api.delete(`/permissions/${id}`).then(() => undefined),
};

export const usersApi = {
  list: (params: PageParams): Promise<PaginatedResponse<UserWithGrants>> =>
    fetchPage<UserWithGrants>("/users", params),
  roles: (userId: number): Promise<UserRole[]> =>
    api.get(`/users/${userId}/roles`).then(unwrap<UserRole[]>),
  updateEmail: (id: number, email: string): Promise<UserWithGrants> =>
    api.put(`/users/${id}`, { user: { email } }).then(unwrap<UserWithGrants>),
  delete: (id: number): Promise<void> => api.delete(`/users/${id}`).then(() => undefined),
  assignRole: (userId: number, roleId: number): Promise<void> =>
    api.post(`/users/${userId}/roles/${roleId}`).then(() => undefined),
  removeRole: (userId: number, roleId: number): Promise<void> =>
    api.delete(`/users/${userId}/roles/${roleId}`).then(() => undefined),
  permissions: fetchUserPermissions,
  grantPermission: (userId: number, permissionId: number) => grantUserPermission(userId, permissionId),
  revokePermission: revokeUserPermission,
  resetPassword: resetUserPassword,
};

export const adminKeys = {
  users: ["admin", "users"] as const,
  usersPage: (page: number) => ["admin", "users", page] as const,
  userRoles: (userId: number) => ["admin", "users", userId, "roles"] as const,
  userPermissions: (userId: number) => ["admin", "users", userId, "permissions"] as const,
  roles: ["admin", "roles"] as const,
  rolesPage: (page: number) => ["admin", "roles", "page", page] as const,
  allRoles: ["admin", "roles", "all"] as const,
  role: (id: number) => ["admin", "roles", "detail", id] as const,
  /** A link changes both ends: invalidate the whole prefix. */
  hierarchy: ["admin", "roles", "hierarchy"] as const,
  roleParents: (id: number) => ["admin", "roles", "hierarchy", id, "parents"] as const,
  roleChildren: (id: number) => ["admin", "roles", "hierarchy", id, "children"] as const,
  permissions: ["admin", "permissions"] as const,
  permissionsPage: (page: number) => ["admin", "permissions", "page", page] as const,
  allPermissions: ["admin", "permissions", "all"] as const,
};
