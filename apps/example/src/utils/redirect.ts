import type { SessionEndReason } from "@rephi/shared-components";

export interface LoginLocationState {
  from?: string;
  sessionEnded?: SessionEndReason;
}

/** Only internal paths are followed, never something like `//evil.example`. */
export function safeRedirectTarget(state: unknown): string | null {
  const from = (state as LoginLocationState | null)?.from;
  return typeof from === "string" && from.startsWith("/") && !from.startsWith("//") ? from : null;
}
