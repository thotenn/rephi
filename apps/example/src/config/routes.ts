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
    requireAdmin?: boolean; // For admin-only pages
  };
}

// Route paths - centralized for easy management
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
    users: "/admin/users",
    roles: "/admin/roles",
    permissions: "/admin/permissions",
  },
} as const;

// Re-export as ROUTES for backward compatibility
export const ROUTES = {
  home: "/",
  auth: ROUTE_PATHS.auth,
  dashboard: {
    home: ROUTE_PATHS.home,
    main: ROUTE_PATHS.pages.dashboard,
    profile: ROUTE_PATHS.pages.profile,
  },
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
          requireAuth: true,
          requireAdmin: true,
        },
      },
      {
        path: "roles",
        element: lazy(() => import("~/routes/admin/roles/index")),
        meta: {
          title: "Roles Management", 
          requireAuth: true,
          requireAdmin: true,
        },
      },
      {
        path: "permissions",
        element: lazy(() => import("~/routes/admin/permissions/index")),
        meta: {
          title: "Permissions Management",
          requireAuth: true,
          requireAdmin: true,
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
