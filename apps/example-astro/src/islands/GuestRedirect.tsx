import { useEffect } from "react";
import { go, isEmbedded } from "~/lib/navigation";
import { useAuthStore } from "~/lib/rephi";
import { ROUTES } from "~/lib/routes";

/**
 * Sends visitors who already have a session to the home page. Used on the
 * public-only pages (welcome, login, register); renders nothing.
 *
 * The check runs once, on arrival. Signing in on the page itself is handled by
 * the form, which knows where to go next (the "redirect back" target).
 */
export default function GuestRedirect() {
  useEffect(() => {
    if (!isEmbedded && useAuthStore.getState().isAuthenticated) {
      go(ROUTES.home, { replace: true });
    }
  }, []);

  return null;
}
