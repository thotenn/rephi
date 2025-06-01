import { useEffect } from "react";
import { Outlet } from "react-router-dom";
import PhoenixSocket from "~/modules/api/socket";
import { useAuthStore } from "~/stores/auth.store";

export default function App() {
  const { isAuthenticated } = useAuthStore();

  useEffect(() => {
    if (isAuthenticated) {
      PhoenixSocket.connect();
    } else {
      PhoenixSocket.disconnect();
    }

    return () => {
      PhoenixSocket.disconnect();
    };
  }, [isAuthenticated]);

  return <Outlet />;
}
