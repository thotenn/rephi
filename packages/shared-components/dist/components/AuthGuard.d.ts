import { default as React, ReactNode } from 'react';

interface AuthGuardProps {
    children: ReactNode;
    isAuthenticated: boolean;
    fallback?: ReactNode;
    redirectTo?: string;
    onUnauthorized?: () => void;
}
export declare const AuthGuard: React.FC<AuthGuardProps>;
export {};
