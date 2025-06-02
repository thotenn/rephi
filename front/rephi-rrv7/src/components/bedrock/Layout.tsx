import { ReactNode, useEffect } from "react";
import { Toaster } from "react-hot-toast";
import toast from "react-hot-toast";
import { channelsProps } from "~/env";
import Header from "./Header";
import { useAuthStore } from "~/stores/auth.store";
import PhoenixSocket from "~/modules/api/socket";
import { useChannel } from "~/hooks/useChannel";

interface LayoutProps {
  children: ReactNode;
  title?: string;
}

export default function Layout({ children, title }: LayoutProps) {
  const { user, isAuthenticated } = useAuthStore();
  const { token } = useAuthStore();
  const { channel, connected } = useChannel(channelsProps.topics.user.lobby);

  // Show loading state while auth is being verified
  if (!isAuthenticated || !user) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-lg text-gray-600">Loading...</div>
      </div>
    );
  }

  useEffect(() => {
    if (token) {
      // Connect socket when user is authenticated
      PhoenixSocket.connect();
    }
    
    return () => {
      // Disconnect on unmount
      PhoenixSocket.disconnect();
    };
  }, [token]);

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