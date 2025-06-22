export interface RouteConfig {
    path: string;
    permissions?: string[];
    roles?: string[];
    requireAuth?: boolean;
    children?: RouteConfig[];
}
export declare const filterRoutesByPermissions: (routes: RouteConfig[], userPermissions: string[], userRoles: string[]) => RouteConfig[];
export declare const createProtectedRoute: (path: string, options?: Partial<RouteConfig>) => RouteConfig;
