/**
 * Builds a user-facing message from a failed request. The shared axios instance
 * rejects with an `Error` whose message is the one sent by the API, when any.
 */
export function describeError(summary: string, error: unknown): string {
  const detail = error instanceof Error ? error.message : "";
  return detail && detail !== "An error occurred" ? `${summary}: ${detail}` : summary;
}
