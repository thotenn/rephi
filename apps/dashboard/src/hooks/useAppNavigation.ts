import { useNavigate, useLocation } from "react-router-dom";
import { useCallback } from "react";
import { ROUTES } from "~/config/routes";
import { useAuthStore } from "~/stores/auth.store";

interface NavigationOptions {
  replace?: boolean;
  state?: unknown;
}

export function useAppNavigation() {
  const navigate = useNavigate();
  const location = useLocation();
  const { isAuthenticated } = useAuthStore();

  // Navigate to a specific route
  const navigateTo = useCallback(
    (path: string, options?: NavigationOptions) => {
      navigate(path, options);
    },
    [navigate]
  );

  // Navigate to login
  const goToLogin = useCallback(
    (options?: NavigationOptions) => {
      navigate(ROUTES.auth.login, {
        ...options,
        state: { from: location, ...(options?.state as Record<string, unknown>) },
      });
    },
    [navigate, location]
  );

  // Navigate to home
  const goToHome = useCallback(
    (options?: NavigationOptions) => {
      const homePath = isAuthenticated ? ROUTES.dashboard.home : ROUTES.home;
      navigate(homePath, options);
    },
    [navigate, isAuthenticated]
  );

  // Go back
  const goBack = useCallback(() => {
    navigate(-1);
  }, [navigate]);

  // Check if current path matches
  const isCurrentPath = useCallback(
    (path: string) => {
      return location.pathname === path;
    },
    [location.pathname]
  );

  return {
    navigateTo,
    goToLogin,
    goToHome,
    goBack,
    isCurrentPath,
    currentPath: location.pathname,
  };
}
