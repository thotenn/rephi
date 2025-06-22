import { ReactNode, useEffect } from "react";
import { toast } from "react-hot-toast";
import { channelsProps } from "~/env";
import Header from "./Header";
import { useChannel } from "~/hooks/useChannel";

interface LayoutProps {
  children: ReactNode;
  title?: string;
}

export default function Layout({ children, title }: LayoutProps) {
  const { channel, connected } = useChannel(channelsProps.topics.user.lobby);

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
      <Header title={title} />
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          {children}
        </div>
      </main>
    </div>
  );
}