/**
 * Route table and URL helpers.
 *
 * This module has no browser or library dependencies on purpose: it is imported
 * by `.astro` files at build time as well as by the React islands.
 */

/** Routes of the app, relative to the configured `base`, without trailing slash. */
export const ROUTES = {
  root: "/",
  home: "/home",
  auth: {
    login: "/login",
    register: "/register",
  },
  pages: {
    profile: "/pages/profile",
    dashboard: "/pages/dashboard",
  },
  admin: {
    root: "/admin",
    users: "/admin/users",
    roles: "/admin/roles",
    permissions: "/admin/permissions",
  },
} as const;

/** Permission that opens each admin screen (and its entry in the Admin menu). */
export const ADMIN_PERMISSIONS = {
  users: "users:view",
  roles: "roles:view",
  permissions: "permissions:view",
} as const;

/** The configured `base` without a trailing slash: "" for "/", "/app/x" for "/app/x/". */
const BASE = import.meta.env.BASE_URL.replace(/\/+$/, "");

/**
 * URL of an internal page: prefixed with `base` and ending with a slash, which
 * is the canonical form of a prerendered `<route>/index.html`.
 */
export function href(route: string): string {
  const path = route.replace(/\/+$/, "");
  return `${BASE}${path}/`;
}

/** URL of a file from `public/`, prefixed with `base`. */
export function asset(path: string): string {
  return `${BASE}/${path.replace(/^\/+/, "")}`;
}

/** Converts a URL pathname back to a route: strips `base` and the trailing slash. */
export function toRoute(pathname: string): string {
  const withoutBase =
    BASE && pathname.startsWith(BASE) ? pathname.slice(BASE.length) : pathname;
  return withoutBase.replace(/\/+$/, "") || "/";
}

/** Whether `pathname` is exactly `route`. */
export function isRoute(pathname: string, route: string): boolean {
  return toRoute(pathname) === route;
}

/** Whether `pathname` is `route` or one of its descendants. */
export function isUnderRoute(pathname: string, route: string): boolean {
  const current = toRoute(pathname);
  return current === route || current.startsWith(`${route}/`);
}

/**
 * Whether `path` is a same-origin path inside this app. Used before following a
 * stored "redirect back" target, so it can never point to another site.
 */
export function isInternalPath(path: string | null | undefined): path is string {
  if (!path || !path.startsWith("/") || path.startsWith("//")) return false;
  return BASE === "" || path === BASE || path.startsWith(`${BASE}/`);
}
