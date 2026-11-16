import type { FieldErrors } from "./types";

export class ApiError extends Error {
  readonly status: number | null;
  readonly detail: string | null;
  readonly fieldErrors: FieldErrors;
  readonly retryAfter: number | null;

  constructor(
    message: string,
    {
      status = null,
      detail = null,
      fieldErrors = {},
      retryAfter = null,
      cause,
    }: {
      status?: number | null;
      detail?: string | null;
      fieldErrors?: FieldErrors;
      retryAfter?: number | null;
      cause?: unknown;
    } = {}
  ) {
    super(message, { cause });
    this.name = "ApiError";
    this.status = status;
    this.detail = detail;
    this.fieldErrors = fieldErrors;
    this.retryAfter = retryAfter;
  }

  get hasFieldErrors(): boolean {
    return Object.keys(this.fieldErrors).length > 0;
  }
}

export function isApiError(error: unknown): error is ApiError {
  return error instanceof ApiError;
}

export function humanizeField(field: string): string {
  const words = field.replace(/_/g, " ").trim();
  return words.charAt(0).toUpperCase() + words.slice(1);
}

export function fieldErrorsToMessage(fieldErrors: FieldErrors): string {
  return Object.entries(fieldErrors)
    .map(([field, messages]) => `${humanizeField(field)} ${messages.join(", ")}`)
    .join(". ");
}

function readFieldErrors(errors: Record<string, unknown>): FieldErrors {
  const result: FieldErrors = {};
  for (const [field, value] of Object.entries(errors)) {
    if (Array.isArray(value)) {
      const messages = value.filter((item): item is string => typeof item === "string");
      if (messages.length > 0) result[field] = messages;
    } else if (typeof value === "string") {
      result[field] = [value];
    }
  }
  return result;
}

function parseRetryAfter(value: unknown): number | null {
  const seconds = Number(value);
  return Number.isFinite(seconds) && seconds >= 0 ? Math.ceil(seconds) : null;
}

function statusFallback(status: number, retryAfter: number | null): string {
  switch (status) {
    case 401:
      return "Your session has ended. Please sign in again.";
    case 403:
      return "You do not have permission to do that.";
    case 404:
      return "Not found.";
    case 409:
      return "The request conflicts with the current state of the data.";
    case 422:
      return "Some fields are invalid.";
    case 429:
      return retryAfter !== null
        ? `Too many attempts. Try again in ${retryAfter} s.`
        : "Too many attempts. Try again later.";
    default:
      return status >= 500 ? "The server failed to process the request." : `Request failed (${status}).`;
  }
}

export function toApiError(
  response: { status: number; data?: unknown; headers?: unknown } | undefined,
  cause?: unknown
): ApiError {
  if (!response) {
    return new ApiError("Could not reach the server. Check your connection and try again.", { cause });
  }

  const { status } = response;
  const headers = (response.headers ?? {}) as Record<string, unknown>;
  const retryAfter = status === 429 ? parseRetryAfter(headers["retry-after"]) : null;
  const body = response.data as { errors?: unknown } | undefined;
  const errors =
    body && typeof body === "object" && body.errors && typeof body.errors === "object"
      ? (body.errors as Record<string, unknown>)
      : null;

  if (errors && typeof errors.detail === "string") {
    return new ApiError(errors.detail, { status, detail: errors.detail, retryAfter, cause });
  }

  if (errors) {
    const fieldErrors = readFieldErrors(errors);
    if (Object.keys(fieldErrors).length > 0) {
      return new ApiError(fieldErrorsToMessage(fieldErrors), { status, fieldErrors, retryAfter, cause });
    }
  }

  return new ApiError(statusFallback(status, retryAfter), { status, retryAfter, cause });
}

export interface ErrorInfo {
  message: string;
  fieldErrors: FieldErrors;
  status: number | null;
}

export function describeError(error: unknown, fallback = "Something went wrong. Please try again."): ErrorInfo {
  if (isApiError(error)) {
    return { message: error.message || fallback, fieldErrors: error.fieldErrors, status: error.status };
  }
  if (error instanceof Error && error.message) {
    return { message: error.message, fieldErrors: {}, status: null };
  }
  return { message: fallback, fieldErrors: {}, status: null };
}

export function getErrorMessage(error: unknown, fallback?: string): string {
  return describeError(error, fallback).message;
}

export function getFieldErrors(error: unknown): FieldErrors {
  return isApiError(error) ? error.fieldErrors : {};
}
