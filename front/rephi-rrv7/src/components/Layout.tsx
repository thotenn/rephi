import { ReactNode, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Toaster } from "react-hot-toast";
import toast from "react-hot-toast";
import { urls, channelsProps } from "~/env";
import Header from "./Header";
import { useAuthStore } from "~/stores/auth.store";
import PhoenixSocket from "~/modules/api/socket";
import { useChannel } from "~/hooks/useChannel";

interface LayoutProps {
  children: ReactNode;
  title?: string;
}

export default function Layout({ children, title }: LayoutProps) {
  const navigate = useNavigate();
  const { token } = useAuthStore();
  const { channel, connected } = useChannel(channelsProps.topics.user.lobby);

  useEffect(() => {
    if (!token) {
      navigate(urls.auth.login);
    } else {
      // Connect socket when user is authenticated
      PhoenixSocket.connect();
    }
    
    return () => {
      // Disconnect on unmount
      PhoenixSocket.disconnect();
    };
  }, [token, navigate]);

  useEffect(() => {
    if (channel && connected) {
      const ref = channel.on(channelsProps.events.user.notification, (payload) => {
        toast.success(payload.message, {
          duration: 5000,
          position: "top-right",
          icon: "🔔",
        });
      });

      return () => {
        channel.off(channelsProps.events.user.notification, ref);
      };
    }
  }, [channel, connected]);

  if (!token) {
    return null;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Toaster />
      <Header title={title} />
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          {children}
        </div>
      </main>
    </div>
  );
}