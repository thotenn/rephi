import { Navigate, useLocation } from "react-router-dom";
import { useAuthStore } from "~/stores/auth.store";
import { ROUTES } from "~/router";

interface AuthGuardProps {
  children: React.ReactNode;
  redirectTo?: string;
  requireAuth?: boolean;
}

export function AuthGuard({ 
  children, 
  redirectTo = ROUTES.auth.login,
  requireAuth = true 
}: AuthGuardProps) {
  const location = useLocation();
  const { isAuthenticated } = useAuthStore();

  // If authentication is required and user is not authenticated
  if (requireAuth && !isAuthenticated) {
    // Redirect to login page with return url
    return <Navigate to={redirectTo} state={{ from: location }} replace />;
  }

  // If authentication is not required and user is authenticated (for login/register pages)
  if (!requireAuth && isAuthenticated) {
    // Redirect to home page
    return <Navigate to={ROUTES.dashboard.home} replace />;
  }

  return <>{children}</>;
}
