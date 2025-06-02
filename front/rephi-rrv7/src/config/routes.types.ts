import type { ComponentType, LazyExoticComponent } from "react";

export interface RouteMeta {
  title?: string;
  description?: string;
  requiresAuth?: boolean;
  permissions?: string[];
}

export interface RouteConfig {
  path: string;
  element?: LazyExoticComponent<ComponentType<any>>;
  flag?: string;
  meta?: RouteMeta;
  children?: RouteConfig[];
  errorElement?: React.ReactNode;
  loader?: () => Promise<any>;
}

export interface ProcessedRoute {
  path?: string;
  index?: boolean;
  element?: React.ReactNode;
  children?: ProcessedRoute[];
  errorElement?: React.ReactNode;
  loader?: () => Promise<any>;
}
