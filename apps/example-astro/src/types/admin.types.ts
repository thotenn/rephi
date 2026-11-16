import type { ManagedUser, Role as RoleSummary } from "~/lib/rephi";

export interface Role {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  is_system: boolean;
  inserted_at: string;
  updated_at: string;
}

export interface Permission {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  /** Grouping only: holding the parent does not grant its children. */
  parent_id: number | null;
  is_system: boolean;
  inserted_at: string;
  updated_at: string;
}

export interface RolePermission {
  id: number;
  name: string;
  slug: string;
  description: string | null;
}

export interface InheritedPermission extends RolePermission {
  inherited_from: RoleSummary[];
}

export interface RoleDetail extends Role {
  permissions: RolePermission[];
  inherited_permissions: InheritedPermission[];
}

export type UserWithGrants = ManagedUser;

export interface UserRole {
  id: number;
  name: string;
  slug: string;
  description: string | null;
}

export interface RoleFormData {
  name: string;
  slug: string;
  description: string;
}

export type PermissionFormData = RoleFormData;
