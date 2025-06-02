# Router Configuration Guide

This document explains how to use and extend the new routing system in the Rephi frontend.

## Overview

The routing system has been refactored to be more modular, type-safe, and maintainable. It uses a configuration-based approach that separates route definitions from the router implementation.

## File Structure

```
src/
├── config/
│   ├── routes.config.ts     # Main route configuration
│   ├── routes.types.ts      # TypeScript types for routes
│   └── routes/              # Modular route configurations
│       └── admin.routes.ts  # Example of modular routes
├── router.tsx               # Main router setup
├── components/
│   └── guards/
│       └── AuthGuard.tsx    # Route protection component
└── hooks/
    └── useAppNavigation.ts  # Navigation utilities
```

## Adding New Routes

### 1. Simple Route

Add a new route to `routes.config.ts`:

```typescript
{
  path: "/new-feature",
  element: lazy(() => import("../routes/new-feature")),
  flag: RouteFlags.AUTHENTICATED,
  meta: {
    title: "New Feature",
    description: "Description of the new feature",
  },
}
```

### 2. Nested Routes

Add routes with children:

```typescript
{
  path: "/section",
  flag: RouteFlags.AUTHENTICATED,
  children: [
    {
      path: "subsection",
      element: lazy(() => import("../routes/section/subsection")),
      flag: RouteFlags.USER,
      meta: {
        title: "Subsection",
      },
    },
  ],
}
```

### 3. Modular Routes

For large sections, create a separate file in `config/routes/`:

```typescript
// config/routes/inventory.routes.ts
export const inventoryRoutes: RouteConfig = {
  path: "/inventory",
  flag: RouteFlags.AUTHENTICATED,
  children: [
    // ... inventory routes
  ],
};
```

Then import it in `routes.config.ts`:

```typescript
import { inventoryRoutes } from "./routes/inventory.routes";

export const routeConfigs: RouteConfig[] = [
  // ... other routes
  inventoryRoutes,
];
```

## Route Flags (Permissions)

Available flags:
- `RouteFlags.PUBLIC` - Accessible by everyone
- `RouteFlags.AUTHENTICATED` - Requires login
- `RouteFlags.USER` - Standard user access
- `RouteFlags.ADMIN` - Admin access only

## Using Navigation

### With Hook

```typescript
import { useAppNavigation } from "~/hooks/useAppNavigation";

function MyComponent() {
  const { goToHome, goToProfile, navigateTo } = useAppNavigation();
  
  return (
    <>
      <button onClick={goToHome}>Home</button>
      <button onClick={goToProfile}>Profile</button>
      <button onClick={() => navigateTo("/custom-path")}>Custom</button>
    </>
  );
}
```

### With Link Component

```typescript
import { Link } from "react-router-dom";
import { ROUTES } from "~/router";

function MyComponent() {
  return (
    <Link to={ROUTES.dashboard.profile}>Go to Profile</Link>
  );
}
```

## Protected Routes

Routes are automatically protected based on their flags. To manually protect a component:

```typescript
import { AuthGuard } from "~/components/guards/AuthGuard";

function ProtectedComponent() {
  return (
    <AuthGuard>
      <YourComponent />
    </AuthGuard>
  );
}
```

## Route Metadata

Add metadata to routes for SEO or other purposes:

```typescript
{
  path: "/about",
  element: lazy(() => import("../routes/about")),
  meta: {
    title: "About Us",
    description: "Learn more about our company",
    requiresAuth: false,
    permissions: ["view_about"],
  },
}
```

## Error Handling

Custom error boundaries can be added to specific routes:

```typescript
{
  path: "/risky-feature",
  element: lazy(() => import("../routes/risky-feature")),
  errorElement: <CustomErrorBoundary />,
}
```

## Best Practices

1. **Keep routes organized**: Group related routes in modular files
2. **Use constants**: Define path constants to avoid typos
3. **Lazy load components**: Always use `lazy()` for better performance
4. **Add metadata**: Include title and description for better UX
5. **Set appropriate flags**: Ensure proper access control
6. **Type safety**: Leverage TypeScript types for route configuration

## Migration from Old Routes

If you need to maintain backward compatibility:

1. Keep the `urls` export in `env.ts`
2. Update it to reference the new `ROUTES` constants
3. Gradually migrate components to use `ROUTES` directly

## Examples

### E-commerce Module Routes

```typescript
// config/routes/ecommerce.routes.ts
export const ecommerceRoutes: RouteConfig = {
  path: "/shop",
  flag: RouteFlags.PUBLIC,
  children: [
    {
      path: "products",
      element: lazy(() => import("../../routes/shop/products")),
      flag: RouteFlags.PUBLIC,
    },
    {
      path: "cart",
      element: lazy(() => import("../../routes/shop/cart")),
      flag: RouteFlags.AUTHENTICATED,
    },
    {
      path: "checkout",
      element: lazy(() => import("../../routes/shop/checkout")),
      flag: RouteFlags.AUTHENTICATED,
    },
  ],
};
```

### Admin Dashboard Routes

```typescript
// config/routes/admin.routes.ts
export const adminRoutes: RouteConfig = {
  path: "/admin",
  flag: RouteFlags.ADMIN,
  element: lazy(() => import("../../routes/admin/layout")),
  children: [
    {
      index: true,
      element: lazy(() => import("../../routes/admin/dashboard")),
    },
    {
      path: "users",
      element: lazy(() => import("../../routes/admin/users")),
    },
  ],
};
```

This new routing system provides better organization, type safety, and scalability for your application.
