import api from "./api";
import type {
  Role,
  Permission,
  UserWithAuth,
  CreateRoleData,
  UpdateRoleData,
  CreatePermissionData,
  UpdatePermissionData,
  ApiResponse,
  ApiListResponse,
} from "~/types/admin.types";

// Roles API
export const rolesApi = {
  // Get all roles
  getAll: (): Promise<ApiListResponse<Role>> =>
    api.get("/roles").then((res) => res.data),

  // Get single role
  getById: (id: number): Promise<ApiResponse<Role>> =>
    api.get(`/roles/${id}`).then((res) => res.data),

  // Create role
  create: (data: CreateRoleData): Promise<ApiResponse<Role>> =>
    api.post("/roles", { role: data }).then((res) => res.data),

  // Update role
  update: (id: number, data: UpdateRoleData): Promise<ApiResponse<Role>> =>
    api.put(`/roles/${id}`, { role: data }).then((res) => res.data),

  // Delete role
  delete: (id: number): Promise<void> =>
    api.delete(`/roles/${id}`).then(() => void 0),

  // Get role permissions
  getPermissions: (roleId: number): Promise<ApiListResponse<Permission>> =>
    api.get(`/roles/${roleId}/permissions`).then((res) => res.data),

  // Assign permission to role
  assignPermission: (roleId: number, permissionId: number): Promise<void> =>
    api.post(`/roles/${roleId}/permissions/${permissionId}`).then(() => void 0),

  // Remove permission from role
  removePermission: (roleId: number, permissionId: number): Promise<void> =>
    api.delete(`/roles/${roleId}/permissions/${permissionId}`).then(() => void 0),
};

// Permissions API
export const permissionsApi = {
  // Get all permissions
  getAll: (): Promise<ApiListResponse<Permission>> =>
    api.get("/permissions").then((res) => res.data),

  // Get single permission
  getById: (id: number): Promise<ApiResponse<Permission>> =>
    api.get(`/permissions/${id}`).then((res) => res.data),

  // Create permission
  create: (data: CreatePermissionData): Promise<ApiResponse<Permission>> =>
    api.post("/permissions", { permission: data }).then((res) => res.data),

  // Update permission
  update: (id: number, data: UpdatePermissionData): Promise<ApiResponse<Permission>> =>
    api.put(`/permissions/${id}`, { permission: data }).then((res) => res.data),

  // Delete permission
  delete: (id: number): Promise<void> =>
    api.delete(`/permissions/${id}`).then(() => void 0),
};

// Users API for admin operations
export const usersApi = {
  // Get all users with roles and permissions
  getAll: (): Promise<ApiListResponse<UserWithAuth>> =>
    api.get("/users").then((res) => res.data),

  // Get single user with roles and permissions
  getById: (id: number): Promise<ApiResponse<UserWithAuth>> =>
    api.get(`/users/${id}`).then((res) => res.data),

  // Get user roles
  getRoles: (userId: number): Promise<ApiListResponse<Role>> =>
    api.get(`/users/${userId}/roles`).then((res) => res.data),

  // Assign role to user
  assignRole: (userId: number, roleId: number): Promise<void> =>
    api.post(`/users/${userId}/roles/${roleId}`).then(() => void 0),

  // Remove role from user
  removeRole: (userId: number, roleId: number): Promise<void> =>
    api.delete(`/users/${userId}/roles/${roleId}`).then(() => void 0),
};