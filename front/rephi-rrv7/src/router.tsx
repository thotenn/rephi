import { createBrowserRouter } from "react-router-dom";
import { lazy, Suspense } from "react";
import App from "./App";

// Lazy load all route components
const IndexPage = lazy(() => import("./routes/index"));
const LoginPage = lazy(() => import("./routes/login"));
const RegisterPage = lazy(() => import("./routes/register"));
const HomePage = lazy(() => import("./routes/home"));
const ProfilePage = lazy(() => import("./routes/pages/profile/index"));
const DashboardPage = lazy(() => import("./routes/pages/dashboard/index"));

// Loading component for lazy-loaded routes
const RouteLoading = () => (
  <div className="min-h-screen flex items-center justify-center">
    <div className="text-lg text-gray-600">Loading...</div>
  </div>
);

// Create and export the router configuration
export const router = createBrowserRouter([
  {
    path: "/",
    element: <App />,
    children: [
      {
        index: true,
        element: (
          <Suspense fallback={<RouteLoading />}>
            <IndexPage />
          </Suspense>
        ),
      },
      {
        path: "login",
        element: (
          <Suspense fallback={<RouteLoading />}>
            <LoginPage />
          </Suspense>
        ),
      },
      {
        path: "register",
        element: (
          <Suspense fallback={<RouteLoading />}>
            <RegisterPage />
          </Suspense>
        ),
      },
      {
        path: "home",
        element: (
          <Suspense fallback={<RouteLoading />}>
            <HomePage />
          </Suspense>
        ),
      },
      {
        path: "pages",
        children: [
          {
            path: "profile",
            element: (
              <Suspense fallback={<RouteLoading />}>
                <ProfilePage />
              </Suspense>
            ),
          },
          {
            path: "dashboard",
            element: (
              <Suspense fallback={<RouteLoading />}>
                <DashboardPage />
              </Suspense>
            ),
          },
        ],
      },
    ],
  },
]);
