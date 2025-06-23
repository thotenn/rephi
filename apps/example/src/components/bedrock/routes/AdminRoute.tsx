import { Navigate } from "react-router-dom";
import { AccessDenied } from "~/components/commons";
import { ROUTE_PATHS } from "~/config/routes";
import { useAuthStore } from "@rephi/shared-components";
import { isAdmin } from "~/utils/auth";

interface AdminRouteProps {
  children: React.ReactNode;
}

export function AdminRoute({ children }: AdminRouteProps) {
  const { user, isAuthenticated } = useAuthStore();

  if (!isAuthenticated) {
    return <Navigate to={ROUTE_PATHS.auth.login} replace />;
  }

  if (!isAdmin(user)) {
    return (
      <AccessDenied />
    );
  }

  return <>{children}</>;
}
