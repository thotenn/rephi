import React, { ReactNode } from 'react';

interface PermissionGuardProps {
  children: ReactNode;
  permissions: string[];
  userPermissions: string[];
  requireAll?: boolean;
  fallback?: ReactNode;
  onUnauthorized?: () => void;
}

export const PermissionGuard: React.FC<PermissionGuardProps> = ({
  children,
  permissions,
  userPermissions,
  requireAll = false,
  fallback = null,
  onUnauthorized
}) => {
  const hasPermission = requireAll
    ? permissions.every(perm => userPermissions.includes(perm))
    : permissions.some(perm => userPermissions.includes(perm));

  React.useEffect(() => {
    if (!hasPermission) {
      onUnauthorized?.();
    }
  }, [hasPermission, onUnauthorized]);

  if (!hasPermission) {
    return <>{fallback}</>;
  }

  return <>{children}</>;
};