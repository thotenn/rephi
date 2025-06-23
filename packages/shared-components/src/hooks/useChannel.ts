import { useEffect, useState } from "react";
import { Channel } from "phoenix";
import PhoenixSocket from "@/controllers/api/socket";

export function useChannel(channelName: string, params = {}) {
  const [channel, setChannel] = useState<Channel | null>(null);
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    let ch: Channel | null = null;

    const connectChannel = () => {
      const socket = PhoenixSocket.getSocket();

      if (!socket) {
        console.error("Socket not connected. Please logout and log back in.");
        setConnected(false);
        return;
      }
      ch = socket.channel(channelName, params);

      ch.join()
        .receive("ok", (resp) => {
          if (process.env.NODE_ENV === "development") {
            console.log(`Successfully joined ${channelName}`, resp);
          }
          setConnected(true);
        })
        .receive("error", ({ reason }) => {
          console.error(`Failed to join ${channelName}:`, reason);
          setConnected(false);
        })
        .receive("timeout", () => {
          if (process.env.NODE_ENV === "development") {
            console.warn(`Timeout joining ${channelName}`);
          }
          setConnected(false);
        });

      setChannel(ch);
    };

    // Small delay to ensure socket is connected
    const timer = setTimeout(connectChannel, 100);

    return () => {
      clearTimeout(timer);
      if (ch) {
        if (process.env.NODE_ENV === "development") {
          console.log(`Leaving channel ${channelName}`);
        }
        ch.leave();
        setConnected(false);
      }
    };
  }, [channelName]); // channelName should be in dependencies

  return { channel, connected };
}
export default useChannel;
