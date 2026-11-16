import { useEffect, useState } from "react";
import { Outlet } from "react-router";
import { toast } from "react-hot-toast";
import { PhoenixSocket, fetchMe, onSessionEnd, useAuthStore } from "@rephi/shared-components";
import RealtimeProvider from "~/realtime/RealtimeProvider";

export default function App() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  // Check a restored session over HTTP before the socket opens: a dead token ends with a 401, not a failed handshake.
  const [bootChecked, setBootChecked] = useState(() => !useAuthStore.getState().isAuthenticated);

  useEffect(() => {
    if (bootChecked) return;
    fetchMe()
      .catch(() => {})
      .finally(() => setBootChecked(true));
  }, [bootChecked]);

  useEffect(() => {
    if (!isAuthenticated || !bootChecked) return;
    PhoenixSocket.connect();
    return () => {
      PhoenixSocket.disconnect();
    };
  }, [isAuthenticated, bootChecked]);

  // Cache is dropped when the next session starts: clearing it here would refetch the page being left without a token.
  useEffect(
    () =>
      onSessionEnd((reason) => {
        if (reason === "unauthorized") {
          toast.error("Your session has ended. Please sign in again.", { id: "session-ended" });
        }
      }),
    []
  );

  return (
    <RealtimeProvider>
      <Outlet />
    </RealtimeProvider>
  );
}
