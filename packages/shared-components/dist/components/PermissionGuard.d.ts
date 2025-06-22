import { default as React, ReactNode } from 'react';

interface PermissionGuardProps {
    children: ReactNode;
    permissions: string[];
    userPermissions: string[];
    requireAll?: boolean;
    fallback?: ReactNode;
    onUnauthorized?: () => void;
}
export declare const PermissionGuard: React.FC<PermissionGuardProps>;
export {};
