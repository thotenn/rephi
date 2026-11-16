/** Body of every successful response that has one: `{"data": ...}`. */
export interface ApiResponse<T> {
  data: T;
}

/** Pagination metadata of a list endpoint (`/api/users`, `/api/roles`, `/api/permissions`). */
export interface PageMeta {
  /** Current page, from 1. */
  page: number;
  /** Entries per page (the server caps it at 100; default 50). */
  page_size: number;
  /** Entries across all pages. */
  total: number;
  /** Number of pages (0 when there are no entries). */
  total_pages: number;
}

/** A page of a list endpoint: `{"data": [...], "meta": {...}}`. */
export interface PaginatedResponse<T> {
  data: T[];
  meta: PageMeta;
}

/** Query string of a list endpoint. */
export interface PageParams {
  page?: number;
  page_size?: number;
}

/** Validation errors (always a 422): field name to messages. */
export type FieldErrors = Record<string, string[]>;

/**
 * Body of every error response. Either a general error with a single
 * `detail` string, or validation errors keyed by field.
 */
export interface ApiErrorBody {
  errors: { detail: string } | FieldErrors;
}
