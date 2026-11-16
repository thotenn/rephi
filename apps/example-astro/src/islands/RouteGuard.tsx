import { useCallback, useState, type ReactNode } from "react";
import AccessDenied from "~/components/react/AccessDenied";
import RouteLoading from "~/components/react/RouteLoading";
import { go } from "~/lib/navigation";
import { AuthGuard, setRedirectPath, useAuthStore, userCan } from "~/lib/rephi";
import { ROUTES } from "~/lib/routes";

interface RouteGuardProps {
  permission?: string;
  children?: ReactNode;
}

// The page stays out of the DOM until the session in the browser allows it.
export default function RouteGuard({ permission, children }: RouteGuardProps) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const user = useAuthStore((state) => state.user);

  // Only visitors arriving signed out get a "redirect back"; after a logout here, login goes home.
  const [arrivedSignedOut] = useState(!isAuthenticated);

  const redirectToLogin = useCallback(() => {
    if (arrivedSignedOut) {
      // Followed by the login only after `isInternalPath()` (see useAuth.ts).
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
