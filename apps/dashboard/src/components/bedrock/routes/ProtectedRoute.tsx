import { Navigate, useLocation } from "react-router-dom";
import { useAuthStore } from "~/stores/auth.store";
import { ROUTES } from "~/config/routes";
import { setRedirectPath } from "~/components/bedrock/routes/routes_utils";

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
