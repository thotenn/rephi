import { useAuthStore } from "../stores/auth.store";
import { userCan, userCanAll, userCanAny, userHasRole } from "../permissions";

export function usePermissions() {
  const user = useAuthStore((state) => state.user);

  return {
    user,
    permissions: user?.permissions.map((permission) => permission.slug) ?? [],
    /** Assigned roles only, not inherited ones: authorize with `permissions`. */
    roles: user?.roles.map((role) => role.slug) ?? [],
    can: (slug: string) => userCan(user, slug),
    canAny: (slugs: readonly string[]) => userCanAny(user, slugs),
    canAll: (slugs: readonly string[]) => userCanAll(user, slugs),
    hasRole: (slug: string) => userHasRole(user, slug),
  };
}
