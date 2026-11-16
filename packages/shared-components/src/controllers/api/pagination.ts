import type { PageMeta, PageParams, PaginatedResponse } from "../../types";
import api from "./api";

/** The largest `page_size` the server accepts (larger values are capped). */
export const MAX_PAGE_SIZE = 100;

/** Fetches one page of a list endpoint (`/users`, `/roles`, `/permissions`). */
export async function fetchPage<T>(path: string, params: PageParams = {}): Promise<PaginatedResponse<T>> {
  const { data } = await api.get<PaginatedResponse<T>>(path, { params });
  return data;
}

/**
 * Fetches every entry of a list endpoint, page after page with the largest
 * page size. Meant for small catalogs (the roles or permissions offered in a
 * picker), not for lists that can grow without bound.
 */
export async function fetchAllPages<T>(path: string, { maxPages = 50 }: { maxPages?: number } = {}): Promise<T[]> {
  const entries: T[] = [];
  for (let page = 1; page <= maxPages; page += 1) {
    const { data, meta } = await fetchPage<T>(path, { page, page_size: MAX_PAGE_SIZE });
    entries.push(...data);
    if (page >= meta.total_pages) break;
  }
  return entries;
}

export function hasNextPage(meta: PageMeta | undefined): boolean {
  return !!meta && meta.page < meta.total_pages;
}

export function hasPreviousPage(meta: PageMeta | undefined): boolean {
  return !!meta && meta.page > 1;
}

/** "21–40 of 57" (1-based, inclusive), or "0 results". */
export function describePage(meta: PageMeta | undefined): string {
  if (!meta || meta.total === 0) return "0 results";
  const first = (meta.page - 1) * meta.page_size + 1;
  const last = Math.min(meta.page * meta.page_size, meta.total);
  if (first > meta.total) return `${meta.total} results`;
  return `${first}–${last} of ${meta.total}`;
}
