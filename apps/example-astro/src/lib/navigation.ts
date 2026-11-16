import { navigate } from "astro:transitions/client";
import { href } from "./routes";

/**
 * True when the page runs inside a frame instead of the top-level window.
 *
 * In development, Astro's client router preloads the next page in a hidden
 * iframe when it contains `client:only` islands (to collect their styles). That
 * throw-away copy shares the stored session with the real page, so code with
 * side effects (opening the socket, redirecting) checks this first. The site is
 * not meant to be framed anyway (see public/_headers).
 */
export const isEmbedded =
  typeof window !== "undefined" && window.self !== window.top;

interface GoOptions {
  /** Replace the current history entry instead of pushing a new one. */
  replace?: boolean;
}

/**
 * Navigates to a full URL path (already including `base`).
 *
 * Goes through Astro's client router, so the persisted runtime island (socket,
 * toasts) survives. `navigate()` falls back to a normal page load on its own
 * when the router is not available.
 */
export function goToPath(path: string, { replace = false }: GoOptions = {}): void {
  void navigate(path, { history: replace ? "replace" : "auto" });
}

/** Navigates to one of the app's routes (see `ROUTES`). */
export function go(route: string, options?: GoOptions): void {
  goToPath(href(route), options);
}
