import React, { ReactNode } from 'react';
import { useAuthStore } from '../stores/auth.store';
import { userCanAll, userCanAny } from '../permissions';

interface PermissionGuardProps {
  children: ReactNode;
  permissions: string[];
  requireAll?: boolean;
  fallback?: ReactNode;
}

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
