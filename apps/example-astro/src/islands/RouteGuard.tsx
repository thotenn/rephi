import { useCallback, useState, type ReactNode } from "react";
import AccessDenied from "~/components/react/AccessDenied";
import RouteLoading from "~/components/react/RouteLoading";
import { go } from "~/lib/navigation";
import { AuthGuard, setRedirectPath, useAuthStore, userCan } from "~/lib/rephi";
import { ROUTES } from "~/lib/routes";

interface RouteGuardProps {
  /** Permission the page requires (e.g. "users:view"); any signed-in user when omitted. */
  permission?: string;
  /** The protected page, passed by Astro as static HTML (see AppLayout.astro). */
  children?: ReactNode;
}

/**
 * Client-side route protection, equivalent to `ProtectedRoute` / `PermissionRoute`
 * in the SPA. The session lives in the browser (persisted store), so the
 * decision can only be taken there: the page content stays out of the document
 * until this island has confirmed the visitor may see it.
 */
export default function RouteGuard({ permission, children }: RouteGuardProps) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const user = useAuthStore((state) => state.user);

  // Remember the requested page only for visitors who arrive signed out. When
  // the session ends on this page (logout, expired token), the next login
  // starts from home.
  const [arrivedSignedOut] = useState(!isAuthenticated);

  const redirectToLogin = useCallback(() => {
    if (arrivedSignedOut) {
      // With its query string (`/admin/users/?page=2`), like the SPA. The login
      // only follows it after `isInternalPath()` (see useAuth.ts).
      const { pathname, search } = window.location;
      setRedirectPath(`${pathname}${search}`);
    }
    go(ROUTES.auth.login, { replace: true });
  }, [arrivedSignedOut]);

  return (
    <AuthGuard
      isAuthenticated={isAuthenticated}
      onUnauthorized={redirectToLogin}
      fallback={<RouteLoading />}
    >
      {permission && !userCan(user, permission) ? <AccessDenied /> : children}
    </AuthGuard>
  );
}
