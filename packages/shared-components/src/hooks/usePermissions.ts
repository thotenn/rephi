import { useMemo } from 'react';

interface UsePermissionsOptions {
  roles?: string[];
  permissions?: string[];
  rolePermissions?: Record<string, string[]>;
}

export const usePermissions = (options: UsePermissionsOptions = {}) => {
  const { roles = [], permissions = [], rolePermissions = {} } = options;

  const allPermissions = useMemo(() => {
    const permSet = new Set(permissions);
    
    roles.forEach(role => {
      const rolePerms = rolePermissions[role] || [];
      rolePerms.forEach(perm => permSet.add(perm));
    });

    return Array.from(permSet);
  }, [roles, permissions, rolePermissions]);

  const hasPermission = (permission: string): boolean => {
    return allPermissions.includes(permission);
  };

  const hasAnyPermission = (perms: string[]): boolean => {
    return perms.some(perm => hasPermission(perm));
  };

  const hasAllPermissions = (perms: string[]): boolean => {
    return perms.every(perm => hasPermission(perm));
  };

  const hasRole = (role: string): boolean => {
    return roles.includes(role);
  };

  const hasAnyRole = (checkRoles: string[]): boolean => {
    return checkRoles.some(role => hasRole(role));
  };

  const hasAllRoles = (checkRoles: string[]): boolean => {
    return checkRoles.every(role => hasRole(role));
  };

  return {
    permissions: allPermissions,
    roles,
    hasPermission,
    hasAnyPermission,
    hasAllPermissions,
    hasRole,
    hasAnyRole,
    hasAllRoles
  };
};