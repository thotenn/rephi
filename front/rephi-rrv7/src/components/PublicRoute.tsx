import { Navigate } from "react-router-dom";
import { useAuthStore } from "~/stores/auth.store";
import { ROUTES } from "~/router";

interface PublicRouteProps {
  children: React.ReactNode;
}

export function PublicRoute({ children }: PublicRouteProps) {
  const { isAuthenticated } = useAuthStore();

  if (isAuthenticated) {
    // Redirect to home if already authenticated
    return <Navigate to={ROUTES.dashboard.home} replace />;
  }

  return <>{children}</>;
}
