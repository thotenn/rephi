import { Navigate, useLocation } from "react-router-dom";
import { useAuthStore } from "~/stores/auth.store";
import { ROUTES } from "~/router";

interface ProtectedRouteProps {
  children: React.ReactNode;
}

const REDIRECT_KEY = "auth_redirect_path";

export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const location = useLocation();
  const { isAuthenticated } = useAuthStore();

  if (!isAuthenticated) {
    // Save the attempted location
    sessionStorage.setItem(REDIRECT_KEY, location.pathname);
    
    // Redirect to login page
    return <Navigate 
      to={ROUTES.auth.login} 
      replace 
    />;
  }

  return <>{children}</>;
}

export function getRedirectPath(): string | null {
  const path = sessionStorage.getItem(REDIRECT_KEY);
  if (path) {
    sessionStorage.removeItem(REDIRECT_KEY);
  }
  return path;
}
