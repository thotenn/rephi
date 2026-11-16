import { Navigate, useLocation } from "react-router";
import { useAuthStore } from "@rephi/shared-components";
import { ROUTE_PATHS } from "~/config/routes";
import { safeRedirectTarget } from "~/utils/redirect";

interface PublicRouteProps {
  children: React.ReactNode;
}

export function PublicRoute({ children }: PublicRouteProps) {
  const location = useLocation();
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);

  if (isAuthenticated) {
    return <Navigate to={safeRedirectTarget(location.state) ?? ROUTE_PATHS.home} replace />;
  }

  return <>{children}</>;
}
