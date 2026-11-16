import { useCallback, useEffect, useMemo, useState } from "react";
import { Toaster, toast } from "react-hot-toast";
import { go, isEmbedded } from "~/lib/navigation";
import { setOnlineCounts, setRealtimeConnected } from "~/lib/realtime";
import { isRoute, ROUTES } from "~/lib/routes";
import {
  fetchMe,
  LOBBY_TOPIC,
  NOTIFICATION_EVENT,
  onSessionEnd,
  PhoenixSocket,
  useAuthStore,
  useChannel,
  presenceCounts,
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

// The only subscriber of these channels, so each notification shows once; presence goes to ~/lib/realtime.
function Notifications({ userId }: { userId: number }) {
  const lobby = useChannel(LOBBY_TOPIC);
  const personal = useChannel(userTopic(userId));

  const online = useMemo(() => presenceCounts(lobby.presences), [lobby.presences]);

  useEffect(() => {
    setRealtimeConnected(lobby.connected);
    return () => setRealtimeConnected(false);
  }, [lobby.connected]);

  useEffect(() => {
    setOnlineCounts(online);
    return () => setOnlineCounts(null);
  }, [online]);

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

export default function AppRuntime() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const userId = useAuthStore((state) => state.user?.id);
  const mustChangePassword = useAuthStore(
    (state) => state.isAuthenticated && !!state.user?.must_change_password
  );
  // Check a restored session over HTTP first: a revoked token gets a 401, not a failed socket handshake.
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

  // Cached data is dropped on the next login: clearing it here would refetch without a token.
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
