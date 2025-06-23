import React, { ReactNode } from 'react';

interface AuthGuardProps {
  children: ReactNode;
  isAuthenticated: boolean;
  fallback?: ReactNode;
  redirectTo?: string;
  onUnauthorized?: () => void;
}

export const AuthGuard: React.FC<AuthGuardProps> = ({
  children,
  isAuthenticated,
  fallback = null,
  redirectTo,
  onUnauthorized
}) => {
  React.useEffect(() => {
    if (!isAuthenticated) {
      if (redirectTo && typeof window !== 'undefined') {
        window.location.href = redirectTo;
      }
      onUnauthorized?.();
    }
  }, [isAuthenticated, redirectTo, onUnauthorized]);

  if (!isAuthenticated) {
    return <>{fallback}</>;
  }

  return <>{children}</>;
};