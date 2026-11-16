# Router Configuration Guide

How routing works in `apps/example` and how to extend it.

## Overview

Routes are declared as data in `src/config/routes.ts` and turned into React Router routes by
`src/router.tsx`, which wraps each page in `Suspense` (lazy loading) and in the guard its `meta`
asks for. The router's basename is the app's Vite `base` (`/app/example`, from the folder name),
so every path below is relative to it.

## File Structure

```
src/
├── config/
│   └── routes.ts                # Route table: ROUTE_PATHS, ADMIN_PERMISSIONS, route arrays
├── router.tsx                   # createBrowserRouter + guards from route meta
├── App.tsx                      # Root element: socket lifecycle, session events, realtime
├── components/bedrock/routes/
│   ├── ProtectedRoute.tsx       # Signed-in users only
│   ├── PermissionRoute.tsx      # Signed-in users with a given permission
│   ├── PublicRoute.tsx          # Signed-out visitors only (login, register)
│   └── RouteLoading.tsx         # Suspense fallback
└── utils/redirect.ts            # Navigation state of the login page
```

## Adding a Route

Add an entry to one of the arrays of `src/config/routes.ts` (`publicRoutes`, `authRoutes`,
`dashboardRoutes`, `adminRoutes`) and, if it is linked from somewhere, its path to `ROUTE_PATHS`:

```typescript
// src/config/routes.ts
export const ROUTE_PATHS = {
  // ...
  reports: "/reports",
} as const;

export const dashboardRoutes: RouteConfig[] = [
  // ...
  {
    path: "reports",
    element: lazy(() => import("~/routes/reports")),
    meta: { title: "Reports", requireAuth: true },
  },
];
```

### Route meta

| Key | Effect |
|---|---|
| `requireAuth: true` | `ProtectedRoute`: signed-out visitors go to the login page and come back after signing in |
| `permission: "users:view"` | `PermissionRoute`: signed in **and** holding the permission; others see the access-denied screen |
| `publicOnly: true` | `PublicRoute`: signed-in users are sent to the page they wanted, or `/home` |
| `title`, `description` | Free metadata |

Authorize by **permission**, not by role: the session's `permissions` are the effective ones
(inherited included), while `roles` only lists the roles assigned directly. The admin screens
use `ADMIN_PERMISSIONS` (`users:view`, `roles:view`, `permissions:view`), and the Admin menu of
`Header.tsx` shows each entry by the same permission.

A path must not end in something that looks like a file extension (`/users/john.doe`): Phoenix
answers those with a 404 instead of the app's `index.html`.

## Nested Routes

```typescript
{
  path: "reports",
  children: [
    { index: true, element: lazy(() => import("~/routes/reports/index")), meta: { requireAuth: true } },
    { path: "monthly", element: lazy(() => import("~/routes/reports/monthly")), meta: { permission: "reports:view" } },
  ],
}
```

## Navigating

```typescript
import { Link, useNavigate } from "react-router";
import { ROUTE_PATHS } from "~/config/routes";

<Link to={ROUTE_PATHS.pages.profile}>Profile</Link>;

const navigate = useNavigate();
navigate(ROUTE_PATHS.home);
```

Logging in, logging out and losing the session do not navigate by hand: the guards follow the
auth store (`isAuthenticated`) and redirect, which also covers a sign-out in another tab and a
token the server revoked.

## Showing Parts of a Page by Permission

```tsx
import { PermissionGuard, usePermissions } from "@rephi/shared-components";

const { can } = usePermissions();
{can("roles:create") && <button>Create Role</button>}

<PermissionGuard permissions={["users:delete"]}>
  <DeleteButton />
</PermissionGuard>
```

## Error Handling

`ErrorBoundary` (the router's `errorElement`) catches render errors of every route. Request
errors are `ApiError`s from `@rephi/shared-components`: show them with `getErrorMessage(error)`
or `describeError(error)` (which also returns the field errors of a 422).
