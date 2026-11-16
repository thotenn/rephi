import type { Permission, Role } from "./auth.types";

export interface ManagedUser {
  id: number;
  email: string;
  must_change_password: boolean;
  roles: Role[];
  permissions: Permission[];
  inserted_at: string;
  updated_at: string;
}

export interface RoleLink {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  is_system: boolean;
  system_link: boolean;
  assigned_by: number | null;
  notes: string | null;
  linked_at: string;
}

export interface RoleParentAssignment {
  role_id: number;
  parent_id: number;
  is_system: boolean;
  assigned_by: number | null;
  notes: string | null;
  inserted_at: string;
}

export interface DirectUserPermission {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  assigned_by: number | null;
  notes: string | null;
  granted_at: string;
}

export interface EffectiveUserPermission {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  direct: boolean;
  roles: Role[];
}

export interface UserPermissions {
  direct: DirectUserPermission[];
  effective: EffectiveUserPermission[];
}

export interface UserPermissionAssignment {
  user_id: number;
  permission_id: number;
  assigned_by: number | null;
  notes: string | null;
  inserted_at: string;
}

export interface PasswordReset {
  user: ManagedUser;
  /** Shown once: the server keeps only its hash. */
  temporary_password: string;
}
