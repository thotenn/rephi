import type { SessionEndReason } from "@rephi/shared-components";

/** Navigation state the login page understands. */
export interface LoginLocationState {
  /** Path (inside the app) the visitor wanted, to return there after login. */
  from?: string;
  /** Set when the session ended while on a protected page. */
  sessionEnded?: SessionEndReason;
}

/** Only internal paths are followed, never something like `//evil.example`. */
export function safeRedirectTarget(state: unknown): string | null {
  const from = (state as LoginLocationState | null)?.from;
  return typeof from === "string" && from.startsWith("/") && !from.startsWith("//") ? from : null;
}
