import type { FieldErrors } from "./types";

/**
 * The error every call through the `api` instance rejects with.
 *
 * The API answers with one of two error bodies:
 *
 *   - `{"errors": {"detail": "..."}}` for a general error, which becomes `detail`;
 *   - `{"errors": {"<field>": ["...", ...]}}` for validation errors (422), which
 *     become `fieldErrors`.
 *
 * `message` is always something that can be shown to a person.
 */
export class ApiError extends Error {
  /** HTTP status, or `null` when no response arrived (network error, CORS, timeout). */
  readonly status: number | null;
  /** The `detail` of a general error. */
  readonly detail: string | null;
  /** Validation errors by field (empty unless the response was a 422 with fields). */
  readonly fieldErrors: FieldErrors;
  /** Seconds to wait before retrying, from the `retry-after` header of a 429. */
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

  /** True for a validation error that names fields. */
  get hasFieldErrors(): boolean {
    return Object.keys(this.fieldErrors).length > 0;
  }
}

export function isApiError(error: unknown): error is ApiError {
  return error instanceof ApiError;
}

/** "password_confirmation" -> "Password confirmation". */
export function humanizeField(field: string): string {
  const words = field.replace(/_/g, " ").trim();
  return words.charAt(0).toUpperCase() + words.slice(1);
}

/** One line per field: "Slug has already been taken". */
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

/**
 * Builds an `ApiError` from what axios received: the status, the body (one of
 * the two error envelopes, or anything else) and the `retry-after` header.
 */
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

/** What a form needs to display an error. */
export interface ErrorInfo {
  /** A sentence for a banner or a toast. */
  message: string;
  /** Messages by field, for the inputs that the server rejected. */
  fieldErrors: FieldErrors;
  status: number | null;
}

/**
 * Turns anything a request can throw into a message plus field errors.
 * `fallback` is used for errors that carry no message of their own.
 */
export function describeError(error: unknown, fallback = "Something went wrong. Please try again."): ErrorInfo {
  if (isApiError(error)) {
    return { message: error.message || fallback, fieldErrors: error.fieldErrors, status: error.status };
  }
  if (error instanceof Error && error.message) {
    return { message: error.message, fieldErrors: {}, status: null };
  }
  return { message: fallback, fieldErrors: {}, status: null };
}

/** The message of `describeError`, for places that only show a line of text. */
export function getErrorMessage(error: unknown, fallback?: string): string {
  return describeError(error, fallback).message;
}

/** The field errors of an `ApiError` (an empty object for anything else). */
export function getFieldErrors(error: unknown): FieldErrors {
  return isApiError(error) ? error.fieldErrors : {};
}
