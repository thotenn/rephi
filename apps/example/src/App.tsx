import { useEffect, useState } from "react";
import { Outlet } from "react-router";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "react-hot-toast";
import { PhoenixSocket, fetchMe, onSessionEnd, useAuthStore } from "@rephi/shared-components";
import RealtimeProvider from "~/realtime/RealtimeProvider";

export default function App() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const queryClient = useQueryClient();
  // A session restored from storage may be stale (roles changed) or dead
  // (token expired or revoked): it is checked once on boot before the socket
  // opens, so a dead token ends the session over HTTP (401) instead of
  // failing a WebSocket handshake.
  const [bootChecked, setBootChecked] = useState(() => !useAuthStore.getState().isAuthenticated);

  useEffect(() => {
    if (bootChecked) return;
    fetchMe()
      .catch(() => {})
      .finally(() => setBootChecked(true));
  }, [bootChecked]);

  // One socket per session: opened on login, closed on logout.
  useEffect(() => {
    if (!isAuthenticated || !bootChecked) return;
    PhoenixSocket.connect();
    return () => {
      PhoenixSocket.disconnect();
    };
  }, [isAuthenticated, bootChecked]);

  // Whatever ended the session, cached data belonged to it. The route guards
  // follow the store and take the user to the login page.
  useEffect(
    () =>
      onSessionEnd((reason) => {
        queryClient.clear();
        if (reason === "unauthorized") {
          toast.error("Your session has ended. Please sign in again.", { id: "session-ended" });
        }
      }),
    [queryClient]
  );

  return (
    <RealtimeProvider>
      <Outlet />
    </RealtimeProvider>
  );
}
