import { Navigate, useLocation } from "react-router";
import { useAuthStore } from "@rephi/shared-components";
import { ROUTE_PATHS } from "~/config/routes";
import type { LoginLocationState } from "~/utils/redirect";

interface ProtectedRouteProps {
  children: React.ReactNode;
}

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

  // After an admin reset, the API refuses everything but the password change.
  if (mustChangePassword && location.pathname !== ROUTE_PATHS.pages.profile) {
    return <Navigate to={ROUTE_PATHS.pages.profile} replace />;
  }

  return <>{children}</>;
}
