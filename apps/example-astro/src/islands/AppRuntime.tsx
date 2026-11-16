import { useEffect } from "react";
import { Toaster, toast } from "react-hot-toast";
import { isEmbedded } from "~/lib/navigation";
import { channelsProps, setRealtimeConnected } from "~/lib/realtime";
import { PhoenixSocket, useAuthStore, useChannel } from "~/lib/rephi";

interface NotificationPayload {
  message: string;
}

/**
 * Joins the lobby and turns its notifications into toasts. This is the only
 * subscriber in the app, so each notification is shown exactly once.
 */
function LobbyNotifications() {
  const { channel, connected } = useChannel(channelsProps.topics.user.lobby);

  useEffect(() => {
    setRealtimeConnected(connected);
    return () => setRealtimeConnected(false);
  }, [connected]);

  useEffect(() => {
    if (!channel) return;

    const ref = channel.on(
      channelsProps.events.user.notification,
      (payload: NotificationPayload) => {
        toast.success(payload.message, {
          duration: 5000,
          position: "top-right",
          icon: "🔔",
        });
      }
    );

    return () => {
      channel.off(channelsProps.events.user.notification, ref);
    };
  }, [channel]);

  return null;
}

/**
 * App-wide runtime: owns the Phoenix socket, the lobby subscription and the
 * toast container.
 *
 * It is rendered once in the base layout with `transition:persist`, so Astro's
 * client router carries this island (and its open socket) from page to page
 * instead of tearing it down on every navigation.
 */
export default function AppRuntime() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  // A framed copy of the page must not open a second socket (see `isEmbedded`).
  const online = isAuthenticated && !isEmbedded;

  useEffect(() => {
    if (!online) return;

    PhoenixSocket.connect();
    return () => {
      PhoenixSocket.disconnect();
    };
  }, [online]);

  return (
    <>
      {online && <LobbyNotifications />}
      <Toaster position="top-right" />
    </>
  );
}
