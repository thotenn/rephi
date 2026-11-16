import { getStorage } from "./storage";

const REDIRECT_KEY = "auth_redirect_path";

export function setRedirectPath(path: string) {
  if (process.env.NODE_ENV === "development") {
    console.log("Setting redirect path:", path);
  }
  getStorage("session")?.setItem(REDIRECT_KEY, path);
}

export function getRedirectPath(): string | null {
  const path = getStorage("session")?.getItem(REDIRECT_KEY) ?? null;
  if (process.env.NODE_ENV === "development") {
    console.log("Getting redirect path:", path);
  }
  return path;
}

export function clearRedirectPath(): void {
  if (process.env.NODE_ENV === "development") {
    console.log("Clearing redirect path");
  }
  getStorage("session")?.removeItem(REDIRECT_KEY);
}




export interface RouteConfig {
  path: string;
  permissions?: string[];
  roles?: string[];
  requireAuth?: boolean;
  children?: RouteConfig[];
}

export const filterRoutesByPermissions = (
  routes: RouteConfig[],
  userPermissions: string[],
  userRoles: string[]
): RouteConfig[] => {
  return routes.filter(route => {
    // Check auth requirement
    if (route.requireAuth && userPermissions.length === 0) {
      return false;
    }

    // Check permissions
    if (route.permissions && route.permissions.length > 0) {
      const hasPermission = route.permissions.some(perm => 
        userPermissions.includes(perm)
      );
      if (!hasPermission) return false;
    }

    // Check roles
    if (route.roles && route.roles.length > 0) {
      const hasRole = route.roles.some(role => 
        userRoles.includes(role)
      );
      if (!hasRole) return false;
    }

    // Filter children recursively
    if (route.children) {
      const filteredChildren = filterRoutesByPermissions(
        route.children,
        userPermissions,
        userRoles
      );
      return filteredChildren.length > 0;
    }

    return true;
  }).map(route => {
    if (route.children) {
      return {
        ...route,
        children: filterRoutesByPermissions(
          route.children,
          userPermissions,
          userRoles
        )
      };
    }
    return route;
  });
};

export const createProtectedRoute = (
  path: string,
  options: Partial<RouteConfig> = {}
): RouteConfig => {
  return {
    path,
    requireAuth: true,
    ...options
  };
};
