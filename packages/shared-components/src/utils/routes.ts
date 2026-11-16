import { getStorage } from "./storage";

const REDIRECT_KEY = "auth_redirect_path";

export function setRedirectPath(path: string): void {
  getStorage("session")?.setItem(REDIRECT_KEY, path);
}

export function getRedirectPath(): string | null {
  return getStorage("session")?.getItem(REDIRECT_KEY) ?? null;
}

export function clearRedirectPath(): void {
  getStorage("session")?.removeItem(REDIRECT_KEY);
}

export interface RouteConfig {
  path: string;
  permissions?: string[];
  roles?: string[];
  requireAuth?: boolean;
  children?: RouteConfig[];
}

export interface RouteAccess {
  isAuthenticated: boolean;
  permissions: readonly string[];
  roles?: readonly string[];
}

function allows(route: RouteConfig, access: RouteAccess): boolean {
  const needsAuth = route.requireAuth || !!route.permissions?.length || !!route.roles?.length;
  if (needsAuth && !access.isAuthenticated) return false;
  if (route.permissions?.length && !route.permissions.some((slug) => access.permissions.includes(slug))) {
    return false;
  }
  if (route.roles?.length && !route.roles.some((slug) => (access.roles ?? []).includes(slug))) {
    return false;
  }
  return true;
}

export function filterRoutesByPermissions(routes: RouteConfig[], access: RouteAccess): RouteConfig[] {
  return routes.flatMap((route) => {
    if (!allows(route, access)) return [];
    if (!route.children) return [route];
    const children = filterRoutesByPermissions(route.children, access);
    return children.length > 0 ? [{ ...route, children }] : [];
  });
}

export function createProtectedRoute(path: string, options: Partial<RouteConfig> = {}): RouteConfig {
  return { path, requireAuth: true, ...options };
}
