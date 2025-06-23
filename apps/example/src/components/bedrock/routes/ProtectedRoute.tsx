import { Navigate, useLocation } from "react-router-dom";
import { ROUTES } from "~/config/routes";
import { useAuthStore, setRedirectPath } from "@rephi/shared-components";

interface ProtectedRouteProps {
  children: React.ReactNode;
}

export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const location = useLocation();
  const { isAuthenticated } = useAuthStore();

  if (!isAuthenticated) {
    // Save the attempted location
    if (process.env.NODE_ENV === "development") {
      console.log("ProtectedRoute: Saving redirect path:", location.pathname);
    }
    setRedirectPath(location.pathname);
    
    // Redirect to login page
    return <Navigate 
      to={ROUTES.auth.login} 
      replace 
    />;
  }

  return <>{children}</>;
}
