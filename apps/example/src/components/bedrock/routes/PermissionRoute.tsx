import { useAuthStore, userCan } from "@rephi/shared-components";
import { AccessDenied } from "~/components/commons";
import { ProtectedRoute } from "./ProtectedRoute";

interface PermissionRouteProps {
  /** Permission slug the page requires, e.g. "users:view". */
  permission: string;
  children: React.ReactNode;
}

/**
 * Signed-in users with `permission` see the page; other signed-in users get
 * the access-denied screen. The server authorizes every request anyway: this
 * only avoids showing a screen whose requests would all fail with 403.
 */
export function PermissionRoute({ permission, children }: PermissionRouteProps) {
  const user = useAuthStore((state) => state.user);

  return (
    <ProtectedRoute>
      {userCan(user, permission) ? children : <AccessDenied />}
    </ProtectedRoute>
  );
}
