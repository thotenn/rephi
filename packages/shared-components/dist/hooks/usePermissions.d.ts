interface UsePermissionsOptions {
    roles?: string[];
    permissions?: string[];
    rolePermissions?: Record<string, string[]>;
}
export declare const usePermissions: (options?: UsePermissionsOptions) => {
    permissions: string[];
    roles: string[];
    hasPermission: (permission: string) => boolean;
    hasAnyPermission: (perms: string[]) => boolean;
    hasAllPermissions: (perms: string[]) => boolean;
    hasRole: (role: string) => boolean;
    hasAnyRole: (checkRoles: string[]) => boolean;
    hasAllRoles: (checkRoles: string[]) => boolean;
};
export {};
