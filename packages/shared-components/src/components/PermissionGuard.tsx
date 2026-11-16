import React, { ReactNode } from 'react';
import { useAuthStore } from '../stores/auth.store';
import { userCanAll, userCanAny } from '../permissions';

interface PermissionGuardProps {
  children: ReactNode;
  /** Permission slugs, e.g. `['users:view']`. */
  permissions: string[];
  /** Require every permission instead of any of them. */
  requireAll?: boolean;
  fallback?: ReactNode;
}

/**
 * Renders `children` when the signed-in user (from the auth store) has the
 * permissions, `fallback` otherwise. UI only: the server authorizes every
 * request on its own.
 */
export const PermissionGuard: React.FC<PermissionGuardProps> = ({
  children,
  permissions,
  requireAll = false,
  fallback = null
}) => {
  const user = useAuthStore((state) => state.user);
  const allowed = requireAll ? userCanAll(user, permissions) : userCanAny(user, permissions);

  return <>{allowed ? children : fallback}</>;
};
