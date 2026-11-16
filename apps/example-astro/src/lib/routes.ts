// No browser or library dependencies: `.astro` files import this at build time.

// Relative to `base`, without trailing slash.
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

export const NEW_RECORD_PARAM = "new";
export const NOTIFY_HASH = "#notify";

export const ADMIN_PERMISSIONS = {
  users: "users:view",
  roles: "roles:view",
  permissions: "permissions:view",
} as const;

const BASE = import.meta.env.BASE_URL.replace(/\/+$/, "");

export function href(route: string): string {
  const path = route.replace(/\/+$/, "");
  return `${BASE}${path}/`;
}

export function asset(path: string): string {
  return `${BASE}/${path.replace(/^\/+/, "")}`;
}

export function toRoute(pathname: string): string {
  const withoutBase =
    BASE && pathname.startsWith(BASE) ? pathname.slice(BASE.length) : pathname;
  return withoutBase.replace(/\/+$/, "") || "/";
}

export function isRoute(pathname: string, route: string): boolean {
  return toRoute(pathname) === route;
}

export function isUnderRoute(pathname: string, route: string): boolean {
  const current = toRoute(pathname);
  return current === route || current.startsWith(`${route}/`);
}

const PROBE_ORIGIN = "http://rephi.invalid";

// Guards a stored "redirect back" target. Resolved like the browser does: `/\evil.example`,
// `/\t/evil.example` and `/app/x/../../elsewhere` start with "/" but leave the site or `base`.
export function isInternalPath(path: string | null | undefined): path is string {
  if (!path || !path.startsWith("/") || path.startsWith("//")) return false;

  let url: URL;
  try {
    url = new URL(path, PROBE_ORIGIN);
  } catch {
    return false;
  }
  if (url.origin !== PROBE_ORIGIN) return false;

  // Checked on the raw path as well, so what the browser receives is what
  // was checked.
  return [path.replace(/[?#].*$/, ""), url.pathname].every(
    (pathname) => BASE === "" || pathname === BASE || pathname.startsWith(`${BASE}/`),
  );
}

export const QUICK_LINKS = {
  newRole: `${href(ROUTES.admin.roles)}?${NEW_RECORD_PARAM}=1`,
  sendNotification: `${href(ROUTES.home)}${NOTIFY_HASH}`,
} as const;
