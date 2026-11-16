import type { User } from "./types";

/*
 * Authorization helpers for the UI. Authorize by permission: `permissions`
 * holds the user's effective permissions (direct, through roles, inherited),
 * while `roles` only lists the roles assigned directly. The server checks
 * every request on its own; these only decide what to show.
 */

/** Whether the user has the permission `slug` (e.g. `"users:view"`). */
export function userCan(user: User | null | undefined, slug: string): boolean {
  return !!user?.permissions?.some((permission) => permission.slug === slug);
}

/** Whether the user has at least one of the permissions. */
export function userCanAny(user: User | null | undefined, slugs: readonly string[]): boolean {
  return slugs.some((slug) => userCan(user, slug));
}

/** Whether the user has every one of the permissions. */
export function userCanAll(user: User | null | undefined, slugs: readonly string[]): boolean {
  return slugs.every((slug) => userCan(user, slug));
}

/**
 * Whether the role `slug` is assigned to the user. Roles a user only inherits
 * (an admin "is" a manager on the server) are not in the list.
 */
export function userHasRole(user: User | null | undefined, slug: string): boolean {
  return !!user?.roles?.some((role) => role.slug === slug);
}
