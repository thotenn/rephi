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
 */
export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const location = useLocation();
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const sessionEndReason = useAuthStore((state) => state.sessionEndReason);

  if (!isAuthenticated) {
    const state: LoginLocationState = sessionEndReason
      ? { sessionEnded: sessionEndReason }
      : { from: `${location.pathname}${location.search}` };
    return <Navigate to={ROUTE_PATHS.auth.login} replace state={state} />;
  }

  return <>{children}</>;
}
