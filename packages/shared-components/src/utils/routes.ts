import { getStorage } from "./storage";

const REDIRECT_KEY = "auth_redirect_path";

/**
 * Remembers where a signed-out visitor wanted to go, for the login to send
 * them back (session storage: per tab, gone when the tab closes). Apps with a
 * client router can carry it in the navigation state instead.
 */
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
  /** Any of these permissions grants access. */
  permissions?: string[];
  /** Any of these roles (assigned, not inherited) grants access. Prefer `permissions`. */
  roles?: string[];
  requireAuth?: boolean;
  children?: RouteConfig[];
}

export interface RouteAccess {
  isAuthenticated: boolean;
  /** Effective permission slugs of the user. */
  permissions: readonly string[];
  /** Assigned role slugs of the user. */
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

/**
 * Keeps the routes the user may see (e.g. to build a menu). A route with
 * children is kept while at least one child is.
 */
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
