import { useCallback, useEffect, useState } from "react";
import { Toaster, toast } from "react-hot-toast";
import { queryClient } from "~/components/react/IslandProviders";
import { isEmbedded } from "~/lib/navigation";
import { setRealtimeConnected } from "~/lib/realtime";
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
  // A session restored from storage may be stale or dead: it is checked once
  // per page load before the socket opens, so a revoked token ends the session
  // over HTTP (401) instead of failing a WebSocket handshake.
  const [bootChecked, setBootChecked] = useState(() => !useAuthStore.getState().isAuthenticated);
  // A framed copy of the page must not open a second socket (see `isEmbedded`).
  const online = isAuthenticated && bootChecked && !isEmbedded;

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

  // Whatever ended the session, cached data belonged to it. `RouteGuard`
  // follows the store and takes the user to the login page.
  useEffect(() => {
    if (isEmbedded) return;
    return onSessionEnd((reason) => {
      queryClient.clear();
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
