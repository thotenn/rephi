import { type ReactNode, useCallback, useMemo } from "react";
import { toast } from "react-hot-toast";
import {
  LOBBY_TOPIC,
  NOTIFICATION_EVENT,
  useAuthStore,
  useChannel,
  presenceCounts,
  useChannelEvent,
  userTopic,
  type RephiNotification,
} from "@rephi/shared-components";
import { RealtimeContext } from "./context";
import NotificationToast from "./NotificationToast";

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

  const online = useMemo(() => presenceCounts(lobby.presences), [lobby.presences]);
  const value = useMemo(() => ({ connected: lobby.connected, online }), [lobby.connected, online]);

  return <RealtimeContext value={value}>{children}</RealtimeContext>;
}
