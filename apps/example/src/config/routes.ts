import { lazy } from "react";

// Route types
export interface RouteConfig {
  path?: string;
  index?: boolean;
  element?: React.LazyExoticComponent<React.ComponentType>;
  children?: RouteConfig[];
  meta?: {
    title?: string;
    description?: string;
    requireAuth?: boolean;
    publicOnly?: boolean; // For login/register pages
    /** Permission the user needs (e.g. "users:view"); implies requireAuth. */
    permission?: string;
  };
}

// Route paths - centralized for easy management. Relative to the router's
// basename (`/app/example`). A path must not end in something that looks like a
// file extension (`/users/john.doe`): Phoenix answers those with a 404 instead
// of the app's index.html.
export const ROUTE_PATHS = {
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

export const QUICK_LINKS = {
  newRole: `${ROUTE_PATHS.admin.roles}?${NEW_RECORD_PARAM}=1`,
  sendNotification: `${ROUTE_PATHS.home}${NOTIFY_HASH}`,
} as const;

/** Permission that opens each admin screen (and its entry in the Admin menu). */
export const ADMIN_PERMISSIONS = {
  users: "users:view",
  roles: "roles:view",
  permissions: "permissions:view",
} as const;

// Auth routes
export const authRoutes: RouteConfig[] = [
  {
    path: "login",
    element: lazy(() => import("~/routes/login")),
    meta: {
      title: "Login",
      requireAuth: false,
      publicOnly: true,
    },
  },
  {
    path: "register",
    element: lazy(() => import("~/routes/register")),
    meta: {
      title: "Register",
      requireAuth: false,
      publicOnly: true,
    },
  },
];

// Dashboard routes
export const dashboardRoutes: RouteConfig[] = [
  {
    path: "home",
    element: lazy(() => import("~/routes/home")),
    meta: {
      title: "Home",
      requireAuth: true,
    },
  },
  {
    path: "pages",
    children: [
      {
        path: "profile",
        element: lazy(() => import("~/routes/pages/profile/index")),
        meta: {
          title: "Profile",
          requireAuth: true,
        },
      },
      {
        path: "dashboard",
        element: lazy(() => import("~/routes/pages/dashboard/index")),
        meta: {
          title: "Dashboard",
          requireAuth: true,
        },
      },
    ],
  },
];

// Public routes
export const publicRoutes: RouteConfig[] = [
  {
    index: true,
    element: lazy(() => import("~/routes/index")),
    meta: {
      title: "Welcome",
      requireAuth: false,
    },
  },
];

// Admin routes
export const adminRoutes: RouteConfig[] = [
  {
    path: "admin",
    children: [
      {
        path: "users",
        element: lazy(() => import("~/routes/admin/users/index")),
        meta: {
          title: "User Management",
          permission: ADMIN_PERMISSIONS.users,
        },
      },
      {
        path: "roles",
        element: lazy(() => import("~/routes/admin/roles/index")),
        meta: {
          title: "Roles Management",
          permission: ADMIN_PERMISSIONS.roles,
        },
      },
      {
        path: "permissions",
        element: lazy(() => import("~/routes/admin/permissions/index")),
        meta: {
          title: "Permissions Management",
          permission: ADMIN_PERMISSIONS.permissions,
        },
      },
    ],
  },
];

// Combine all routes
export const allRoutes: RouteConfig[] = [
  ...publicRoutes,
  ...authRoutes,
  ...dashboardRoutes,
  ...adminRoutes,
];
