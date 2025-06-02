import { createBrowserRouter, type RouteObject } from "react-router-dom";
import { Suspense } from "react";
import App from "./App";
import { allRoutes, type RouteConfig } from "./config/routes";
import { ProtectedRoute } from "./components/bedrock/routes/ProtectedRoute";
import { PublicRoute } from "./components/bedrock/routes/PublicRoute";
import RouteLoading from "./components/bedrock/routes/RouteLoading";
import ErrorBoundary from "./components/ErrorBoundary";

// Helper function to process routes
const processRoutes = (routes: RouteConfig[]): RouteObject[] => {
  return routes.map(route => {
    const processedRoute: RouteObject = {};
    
    // Handle path or index
    if (route.index === true) {
      processedRoute.index = true;
      processedRoute.path = undefined;
    } else if (route.path) {
      processedRoute.path = route.path;
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
      if (route.meta?.requireAuth) {
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
]);
