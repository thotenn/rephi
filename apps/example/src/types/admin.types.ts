export interface Role {
  id: number;
  name: string;
  slug: string;
  description?: string;
  inserted_at: string;
  updated_at: string;
}

export interface Permission {
  id: number;
  name: string;
  slug: string;
  description?: string;
  inserted_at: string;
  updated_at: string;
}

export interface UserWithAuth {
  id: number;
  email: string;
  roles: Role[];
  permissions: Permission[];
  inserted_at: string;
  updated_at: string;
}

export interface CreateRoleData {
  name: string;
  slug: string;
  description?: string;
}

export interface UpdateRoleData {
  name?: string;
  slug?: string;
  description?: string;
}

export interface CreatePermissionData {
  name: string;
  slug: string;
  description?: string;
}

export interface UpdatePermissionData {
  name?: string;
  slug?: string;
  description?: string;
}

export interface ApiResponse<T> {
  data: T;
}

export interface ApiListResponse<T> {
  data: T[];
}