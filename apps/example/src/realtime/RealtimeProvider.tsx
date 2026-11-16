import { type ReactNode, useCallback, useMemo } from "react";
import { toast } from "react-hot-toast";
import {
  LOBBY_TOPIC,
  NOTIFICATION_EVENT,
  useAuthStore,
  useChannel,
  useChannelEvent,
  userTopic,
  type RephiNotification,
} from "@rephi/shared-components";
import { RealtimeContext } from "./context";
import NotificationToast from "./NotificationToast";

/**
 * Joins the notification channels once for the whole app and turns their
 * events into toasts: `user:lobby` (broadcasts to everybody) and `user:<id>`
 * (notifications for the signed-in user only). Being the only subscriber, a
 * notification is shown exactly once whatever the page.
 *
 * The socket itself is opened and closed by `App`, following the session.
 */
export default function RealtimeProvider({ children }: { children: ReactNode }) {
  const userId = useAuthStore((state) => state.user?.id);

  const lobby = useChannel(LOBBY_TOPIC);
  const personal = useChannel(userId ? userTopic(userId) : null);

  const showNotification = useCallback((notification: RephiNotification) => {
    toast.success(<NotificationToast notification={notification} />, {
      duration: 5000,
      position: "top-right",
      icon: "🔔",
    });
  }, []);

  useChannelEvent(lobby.channel, NOTIFICATION_EVENT, showNotification);
  useChannelEvent(personal.channel, NOTIFICATION_EVENT, showNotification);

  const value = useMemo(() => ({ connected: lobby.connected }), [lobby.connected]);

  return <RealtimeContext value={value}>{children}</RealtimeContext>;
}
