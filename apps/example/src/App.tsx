import { useEffect } from "react";
import { Outlet } from "react-router-dom";
import { PhoenixSocket, useAuthStore } from "@rephi/shared-components";

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

  return (
    <>
      <Outlet />
    </>
  );
}
