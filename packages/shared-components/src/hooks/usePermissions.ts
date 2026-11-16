import { useAuthStore } from "../stores/auth.store";
import { userCan, userCanAll, userCanAny, userHasRole } from "../permissions";

/**
 * Permission checks against the signed-in user of the auth store. Re-renders
 * when the user changes (login, logout, `fetchMe()`).
 */
export function usePermissions() {
  const user = useAuthStore((state) => state.user);

  return {
    user,
    /** Effective permission slugs of the user. */
    permissions: user?.permissions.map((permission) => permission.slug) ?? [],
    /** Slugs of the roles assigned to the user (inherited roles are not listed). */
    roles: user?.roles.map((role) => role.slug) ?? [],
    can: (slug: string) => userCan(user, slug),
    canAny: (slugs: readonly string[]) => userCanAny(user, slugs),
    canAll: (slugs: readonly string[]) => userCanAll(user, slugs),
    hasRole: (slug: string) => userHasRole(user, slug),
  };
}
