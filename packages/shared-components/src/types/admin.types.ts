import type { Permission, Role } from "./auth.types";

/**
 * A user as the user-management endpoints describe it (`/api/users`, the
 * password reset): the roles assigned to it and the permissions granted to it
 * directly.
 */
export interface ManagedUser {
  id: number;
  email: string;
  /** An administrator reset its password and it has not set a new one yet. */
  must_change_password: boolean;
  /** Assigned roles (not the inherited ones). */
  roles: Role[];
  /** Granted to the user directly (not through roles). */
  permissions: Permission[];
  inserted_at: string;
  updated_at: string;
}

/**
 * A role linked to another in the hierarchy: one of its parents
 * (`GET /api/roles/:id/parents`) or children (`GET /api/roles/:id/children`),
 * with the attributes of the link.
 */
export interface RoleLink {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  /** The linked role is a system role. */
  is_system: boolean;
  /** The link belongs to the default hierarchy: it cannot be removed (409). */
  system_link: boolean;
  /** Who made the link (null for seeded links, or once that user is deleted). */
  assigned_by: number | null;
  notes: string | null;
  linked_at: string;
}

/** `POST /api/roles/:role_id/parents/:parent_id`: the new link. */
export interface RoleParentAssignment {
  /** The child role. */
  role_id: number;
  parent_id: number;
  is_system: boolean;
  assigned_by: number | null;
  notes: string | null;
  inserted_at: string;
}

/** A permission granted to the user itself, with the grant. */
export interface DirectUserPermission {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  assigned_by: number | null;
  notes: string | null;
  granted_at: string;
}

/** A permission the user holds, and where it comes from. */
export interface EffectiveUserPermission {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  /** Granted to the user itself. */
  direct: boolean;
  /**
   * The roles that grant it: assigned to the user or inherited through the
   * hierarchy (the role the permission is assigned to). Empty when only direct.
   */
  roles: Role[];
}

/** `GET /api/users/:id/permissions`. */
export interface UserPermissions {
  /** Revocable with `revokeUserPermission`. */
  direct: DirectUserPermission[];
  /** Everything the user may do (what its session lists as `permissions`). */
  effective: EffectiveUserPermission[];
}

/** `POST /api/users/:user_id/permissions/:permission_id`: the new grant. */
export interface UserPermissionAssignment {
  user_id: number;
  permission_id: number;
  assigned_by: number | null;
  notes: string | null;
  inserted_at: string;
}

/** `POST /api/users/:id/password`. */
export interface PasswordReset {
  /** The user, now with `must_change_password: true`. */
  user: ManagedUser;
  /**
   * Shown once: the server does not keep it and cannot return it again. It
   * only lets the user sign in and choose a new password.
   */
  temporary_password: string;
}
