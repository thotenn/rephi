import { useCallback, useState, type ReactNode } from "react";
import AccessDenied from "~/components/react/AccessDenied";
import RouteLoading from "~/components/react/RouteLoading";
import { isAdmin } from "~/lib/auth";
import { go } from "~/lib/navigation";
import { AuthGuard, setRedirectPath, useAuthStore } from "~/lib/rephi";
import { ROUTES } from "~/lib/routes";

interface RouteGuardProps {
  /** `auth`: any signed-in user. `admin`: users with the `admin` role. */
  access?: "auth" | "admin";
  /** The protected page, passed by Astro as static HTML (see AppLayout.astro). */
  children?: ReactNode;
}

/**
 * Client-side route protection, equivalent to `ProtectedRoute` / `AdminRoute`
 * in the SPA. The session lives in the browser (persisted store), so the
 * decision can only be taken there: the page content stays out of the document
 * until this island has confirmed the visitor may see it.
 */
export default function RouteGuard({ access = "auth", children }: RouteGuardProps) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const user = useAuthStore((state) => state.user);

  // Remember the requested page only for visitors who arrive signed out. When
  // the session ends on this page (logout), the next login starts from home.
  const [arrivedSignedOut] = useState(!isAuthenticated);

  const redirectToLogin = useCallback(() => {
    if (arrivedSignedOut) {
      setRedirectPath(window.location.pathname);
    }
    go(ROUTES.auth.login, { replace: true });
  }, [arrivedSignedOut]);

  return (
    <AuthGuard
      isAuthenticated={isAuthenticated}
      onUnauthorized={redirectToLogin}
      fallback={<RouteLoading />}
    >
      {access === "admin" && !isAdmin(user) ? <AccessDenied /> : children}
    </AuthGuard>
  );
}
