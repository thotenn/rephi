import { useCallback, useEffect, useState } from "react";
import { Toaster, toast } from "react-hot-toast";
import { go, isEmbedded } from "~/lib/navigation";
import { setRealtimeConnected } from "~/lib/realtime";
import { isRoute, ROUTES } from "~/lib/routes";
import {
  fetchMe,
  LOBBY_TOPIC,
  NOTIFICATION_EVENT,
  onSessionEnd,
  PhoenixSocket,
  useAuthStore,
  useChannel,
  useChannelEvent,
  userTopic,
  type RephiNotification,
} from "~/lib/rephi";

function NotificationToast({ notification }: { notification: RephiNotification }) {
  // Rendered by React as text, never as HTML.
  return (
    <span className="flex flex-col">
      <span>{notification.message}</span>
      <span className="text-xs text-gray-500">
        {notification.from ? `From ${notification.from.email}` : "System notification"}
      </span>
    </span>
  );
}

/**
 * Joins `user:lobby` (broadcasts) and `user:<id>` (the user's own
 * notifications) and turns their events into toasts. This is the only
 * subscriber in the app, so each notification is shown exactly once.
 */
function Notifications({ userId }: { userId: number }) {
  const lobby = useChannel(LOBBY_TOPIC);
  const personal = useChannel(userTopic(userId));

  useEffect(() => {
    setRealtimeConnected(lobby.connected);
    return () => setRealtimeConnected(false);
  }, [lobby.connected]);

  const show = useCallback((notification: RephiNotification) => {
    toast.success(<NotificationToast notification={notification} />, {
      duration: 5000,
      position: "top-right",
      icon: "🔔",
    });
  }, []);

  useChannelEvent(lobby.channel, NOTIFICATION_EVENT, show);
  useChannelEvent(personal.channel, NOTIFICATION_EVENT, show);

  return null;
}

// This island persists across navigations, hence the astro:page-load listener.
function usePasswordChangeRedirect(mustChangePassword: boolean) {
  useEffect(() => {
    if (!mustChangePassword || isEmbedded) return;

    const enforce = () => {
      if (isRoute(window.location.pathname, ROUTES.pages.profile)) return;
      toast("Choose a new password to continue.", { id: "must-change-password", icon: "🔑" });
      go(ROUTES.pages.profile, { replace: true });
    };

    enforce();
    document.addEventListener("astro:page-load", enforce);
    return () => document.removeEventListener("astro:page-load", enforce);
  }, [mustChangePassword]);
}

/**
 * App-wide runtime: owns the Phoenix socket, the notification channels, the
 * reaction to a lost session and the toast container.
 *
 * It is rendered once in the base layout with `transition:persist`, so Astro's
 * client router carries this island (and its open socket) from page to page
 * instead of tearing it down on every navigation.
 */
export default function AppRuntime() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const userId = useAuthStore((state) => state.user?.id);
  const mustChangePassword = useAuthStore(
    (state) => state.isAuthenticated && !!state.user?.must_change_password
  );
  // A session restored from storage may be stale or dead: it is checked once
  // per page load before the socket opens, so a revoked token ends the session
  // over HTTP (401) instead of failing a WebSocket handshake.
  const [bootChecked, setBootChecked] = useState(() => !useAuthStore.getState().isAuthenticated);
  // A framed copy of the page must not open a second socket (see `isEmbedded`).
  const online = isAuthenticated && bootChecked && !isEmbedded;

  usePasswordChangeRedirect(mustChangePassword);

  useEffect(() => {
    if (bootChecked || isEmbedded) return;
    fetchMe()
      .catch(() => {})
      .finally(() => setBootChecked(true));
  }, [bootChecked]);

  useEffect(() => {
    if (!online) return;
    PhoenixSocket.connect();
    return () => {
      PhoenixSocket.disconnect();
    };
  }, [online]);

  // `RouteGuard` follows the store and takes the user to the login page; this
  // only tells the user why. Cached data is dropped when the next session
  // starts (`useLogin` / `useRegister`): clearing it here would make the
  // queries of the page being left refetch without a token.
  useEffect(() => {
    if (isEmbedded) return;
    return onSessionEnd((reason) => {
      if (reason === "unauthorized") {
        toast.error("Your session has ended. Please sign in again.", { id: "session-ended" });
      }
    });
  }, []);

  return (
    <>
      {online && userId !== undefined && <Notifications userId={userId} />}
      <Toaster position="top-right" />
    </>
  );
}
