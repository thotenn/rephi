import { Navigate, useLocation } from "react-router";
import { useAuthStore } from "@rephi/shared-components";
import { ROUTE_PATHS } from "~/config/routes";
import type { LoginLocationState } from "~/utils/redirect";

interface ProtectedRouteProps {
  children: React.ReactNode;
}

/**
 * Renders the page for signed-in users and sends everyone else to the login.
 *
 * A visitor who arrives signed out is sent back here after logging in (the
 * location travels in the navigation state). When the session ends on this
 * page (logout, expired token) the login starts fresh instead.
 *
 * A user whose password an administrator reset (`must_change_password`) is
 * kept on the profile page, where the password form is, until a new password
 * is set: the API refuses everything else meanwhile.
 */
export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const location = useLocation();
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const sessionEndReason = useAuthStore((state) => state.sessionEndReason);
  const mustChangePassword = useAuthStore((state) => !!state.user?.must_change_password);

  if (!isAuthenticated) {
    const state: LoginLocationState = sessionEndReason
      ? { sessionEnded: sessionEndReason }
      : { from: `${location.pathname}${location.search}` };
    return <Navigate to={ROUTE_PATHS.auth.login} replace state={state} />;
  }

  if (mustChangePassword && location.pathname !== ROUTE_PATHS.pages.profile) {
    return <Navigate to={ROUTE_PATHS.pages.profile} replace />;
  }

  return <>{children}</>;
}
