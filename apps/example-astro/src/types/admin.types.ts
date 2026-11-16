import type { Permission as GrantSummary, Role as RoleSummary } from "~/lib/rephi";

/** A role as `/api/roles` returns it. */
export interface Role {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  /** Seeded roles: they cannot be deleted and their slug cannot change. */
  is_system: boolean;
  inserted_at: string;
  updated_at: string;
}

/** A permission as `/api/permissions` returns it. */
export interface Permission {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  /** Grouping only: holding the parent does not grant its children. */
  parent_id: number | null;
  /** Seeded permissions: they cannot be deleted and their slug cannot change. */
  is_system: boolean;
  inserted_at: string;
  updated_at: string;
}

/** A permission of a role detail. */
export interface RolePermission {
  id: number;
  name: string;
  slug: string;
  description: string | null;
}

/** A permission the role only inherits, with the ancestor roles that grant it. */
export interface InheritedPermission extends RolePermission {
  inherited_from: RoleSummary[];
}

/** `GET /api/roles/:id`: the permissions assigned to the role, and the inherited ones. */
export interface RoleDetail extends Role {
  /** Assigned to the role itself: these can be removed. */
  permissions: RolePermission[];
  /** Inherited from parent roles and not assigned directly: read-only here. */
  inherited_permissions: InheritedPermission[];
}

/** A user as `/api/users` returns it: assigned roles and direct permissions. */
export interface UserWithGrants {
  id: number;
  email: string;
  roles: RoleSummary[];
  /** Granted to the user directly (not through roles). */
  permissions: GrantSummary[];
  inserted_at: string;
  updated_at: string;
}

/** A role offered in the user-role picker (`/api/users/:id/roles`). */
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
