import { useAuthStore, userCan } from "@rephi/shared-components";
import { AccessDenied } from "~/components/commons";
import { ProtectedRoute } from "./ProtectedRoute";

interface PermissionRouteProps {
  permission: string;
  children: React.ReactNode;
}

export function PermissionRoute({ permission, children }: PermissionRouteProps) {
  const user = useAuthStore((state) => state.user);

  return (
    <ProtectedRoute>
      {userCan(user, permission) ? children : <AccessDenied />}
    </ProtectedRoute>
  );
}
