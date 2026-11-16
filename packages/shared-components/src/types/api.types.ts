export interface ApiResponse<T> {
  data: T;
}

export interface PageMeta {
  page: number;
  page_size: number;
  total: number;
  total_pages: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  meta: PageMeta;
}

export interface PageParams {
  page?: number;
  page_size?: number;
}

export type FieldErrors = Record<string, string[]>;

export interface ApiErrorBody {
  errors: { detail: string } | FieldErrors;
}
