import { navigate } from "astro:transitions/client";
import { href } from "./routes";

// In dev, Astro preloads pages with client:only islands in a hidden iframe that shares the session.
export const isEmbedded =
  typeof window !== "undefined" && window.self !== window.top;

interface GoOptions {
  replace?: boolean;
}

// Through Astro's client router, so the persisted runtime island survives the navigation.
export function goToPath(path: string, { replace = false }: GoOptions = {}): void {
  void navigate(path, { history: replace ? "replace" : "auto" });
}

export function go(route: string, options?: GoOptions): void {
  goToPath(href(route), options);
}
