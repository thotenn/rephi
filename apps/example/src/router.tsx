import { Suspense } from "react";
import { createBrowserRouter, type RouteObject } from "react-router-dom";
import { env } from "@rephi/shared-components";
import App from "./App";
import { allRoutes, type RouteConfig } from "./config/routes";
import { ProtectedRoute } from "./components/bedrock/routes/ProtectedRoute";
import { PublicRoute } from "./components/bedrock/routes/PublicRoute";
import { AdminRoute } from "./components/bedrock/routes/AdminRoute";
import RouteLoading from "./components/bedrock/routes/RouteLoading";
import ErrorBoundary from "./components/ErrorBoundary";

// Helper function to process routes
const processRoutes = (routes: RouteConfig[]): RouteObject[] => {
  return routes.map(route => {
    let processedRoute: RouteObject;
    
    // Handle path or index
    if (route.index === true) {
      processedRoute = { index: true };
    } else {
      processedRoute = route.path ? { path: route.path } : {};
    }
    
    // Handle element with Suspense and protection
    if (route.element) {
      const LazyComponent = route.element;
      const element = (
        <Suspense fallback={<RouteLoading />}>
          <LazyComponent />
        </Suspense>
      );
      
      // Wrap with appropriate route protection
      if (route.meta?.requireAdmin) {
        processedRoute.element = (
          <AdminRoute>
            {element}
          </AdminRoute>
        );
      } else if (route.meta?.requireAuth) {
        processedRoute.element = (
          <ProtectedRoute>
            {element}
          </ProtectedRoute>
        );
      } else if (route.meta?.publicOnly) {
        processedRoute.element = (
          <PublicRoute>
            {element}
          </PublicRoute>
        );
      } else {
        processedRoute.element = element;
      }
    }
    
    // Handle children recursively
    if (route.children) {
      processedRoute.children = processRoutes(route.children);
    }
    
    return processedRoute;
  });
};

// Create and export the router configuration
export const router = createBrowserRouter([
  {
    path: "/",
    element: <App />,
    errorElement: <ErrorBoundary />,
    children: processRoutes(allRoutes),
  },
], {
  basename: env.APPS.example.basename,
});
