import { createBrowserRouter } from "react-router-dom";
import { Suspense } from "react";
import App from "./App";
import { allRoutes, type RouteConfig } from "./config/routes";
import { ProtectedRoute } from "./components/bedrock/ProtectedRoute";
import { PublicRoute } from "./components/bedrock/PublicRoute";

// Loading component for lazy-loaded routes
const RouteLoading = () => (
  <div className="min-h-screen flex items-center justify-center">
    <div className="animate-pulse text-lg text-gray-600">Loading...</div>
  </div>
);

// Error boundary component
const ErrorBoundary = () => (
  <div className="min-h-screen flex items-center justify-center">
    <div className="text-center">
      <h1 className="text-2xl font-bold text-red-600 mb-4">Oops! Something went wrong</h1>
      <p className="text-gray-600">Please try refreshing the page or contact support if the problem persists.</p>
    </div>
  </div>
);

// Route paths - centralized for easy management
export const ROUTES = {
  home: "/",
  auth: {
    login: "/login",
    register: "/register",
  },
  dashboard: {
    home: "/home",
    main: "/pages/dashboard",
    profile: "/pages/profile",
  },
} as const;

// Helper function to process routes
const processRoutes = (routes: RouteConfig[]): any[] => {
  return routes.map(route => {
    const processedRoute: any = {};
    
    // Handle path or index
    if (route.index) {
      processedRoute.index = true;
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
