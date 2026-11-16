import {
  api,
  fetchAllPages,
  fetchPage,
  type ApiResponse,
  type PageParams,
  type PaginatedResponse,
} from "~/lib/rephi";
import type {
  Permission,
  PermissionFormData,
  Role,
  RoleDetail,
  RoleFormData,
  UserRole,
  UserWithGrants,
} from "~/types/admin.types";

/** Rows per page of the admin tables (the server default is 50, its maximum 100). */
export const ADMIN_PAGE_SIZE = 20;

const unwrap = <T>(res: { data: ApiResponse<T> }) => res.data.data;

export const rolesApi = {
  list: (params: PageParams): Promise<PaginatedResponse<Role>> => fetchPage<Role>("/roles", params),
  /** Every role (all pages), for pickers. */
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
};

export const permissionsApi = {
  list: (params: PageParams): Promise<PaginatedResponse<Permission>> =>
    fetchPage<Permission>("/permissions", params),
  /** Every permission (all pages), for pickers. */
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
  /** Only the email can change here; users change their own password on their profile. */
  updateEmail: (id: number, email: string): Promise<UserWithGrants> =>
    api.put(`/users/${id}`, { user: { email } }).then(unwrap<UserWithGrants>),
  delete: (id: number): Promise<void> => api.delete(`/users/${id}`).then(() => undefined),
  assignRole: (userId: number, roleId: number): Promise<void> =>
    api.post(`/users/${userId}/roles/${roleId}`).then(() => undefined),
  removeRole: (userId: number, roleId: number): Promise<void> =>
    api.delete(`/users/${userId}/roles/${roleId}`).then(() => undefined),
};

/** react-query keys of the admin data. */
export const adminKeys = {
  users: ["admin", "users"] as const,
  usersPage: (page: number) => ["admin", "users", page] as const,
  userRoles: (userId: number) => ["admin", "users", userId, "roles"] as const,
  roles: ["admin", "roles"] as const,
  rolesPage: (page: number) => ["admin", "roles", "page", page] as const,
  allRoles: ["admin", "roles", "all"] as const,
  role: (id: number) => ["admin", "roles", "detail", id] as const,
  permissions: ["admin", "permissions"] as const,
  permissionsPage: (page: number) => ["admin", "permissions", "page", page] as const,
  allPermissions: ["admin", "permissions", "all"] as const,
};
