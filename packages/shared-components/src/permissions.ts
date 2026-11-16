import type { User } from "./types";

export function userCan(user: User | null | undefined, slug: string): boolean {
  return !!user?.permissions?.some((permission) => permission.slug === slug);
}

export function userCanAny(user: User | null | undefined, slugs: readonly string[]): boolean {
  return slugs.some((slug) => userCan(user, slug));
}

export function userCanAll(user: User | null | undefined, slugs: readonly string[]): boolean {
  return slugs.every((slug) => userCan(user, slug));
}

/** Assigned roles only: roles the user inherits on the server are not listed. Prefer `userCan`. */
export function userHasRole(user: User | null | undefined, slug: string): boolean {
  return !!user?.roles?.some((role) => role.slug === slug);
}
