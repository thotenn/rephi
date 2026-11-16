import { useEffect } from "react";
import { go, isEmbedded } from "~/lib/navigation";
import { useAuthStore } from "~/lib/rephi";
import { ROUTES } from "~/lib/routes";

// Checked once, on arrival: after signing in on the page, the form decides where to go.
export default function GuestRedirect() {
  useEffect(() => {
    if (!isEmbedded && useAuthStore.getState().isAuthenticated) {
      go(ROUTES.home, { replace: true });
    }
  }, []);

  return null;
}
