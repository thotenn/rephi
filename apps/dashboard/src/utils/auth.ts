import type { User } from "~/types/auth.types";

/**
 * Check if user has admin role
 */
export const isAdmin = (user: User | null): boolean => {
  if (!user || !user.roles) return false;
  return user.roles.some(role => role.slug === "admin");
};

/**
 * Check if user has specific role
 */
export const hasRole = (user: User | null, roleSlug: string): boolean => {
  if (!user || !user.roles) return false;
  return user.roles.some(role => role.slug === roleSlug);
};

/**
 * Check if user has specific permission
 */
export const hasPermission = (user: User | null, permissionSlug: string): boolean => {
  if (!user || !user.permissions) return false;
  return user.permissions.some(permission => permission.slug === permissionSlug);
};

/**
 * Check if user has any of the specified roles
 */
export const hasAnyRole = (user: User | null, roleSlugs: string[]): boolean => {
  if (!user || !user.roles) return false;
  return user.roles.some(role => roleSlugs.includes(role.slug));
};

/**
 * Check if user has any of the specified permissions
 */
export const hasAnyPermission = (user: User | null, permissionSlugs: string[]): boolean => {
  if (!user || !user.permissions) return false;
  return user.permissions.some(permission => permissionSlugs.includes(permission.slug));
};