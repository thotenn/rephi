import { useEffect, useState } from 'react';
import { Channel } from 'phoenix';
import PhoenixSocket from '~/modules/api/socket';

export function useChannel(channelName: string, params = {}) {
  const [channel, setChannel] = useState<Channel | null>(null);
  const [connected, setConnected] = useState(false);
  
  useEffect(() => {
    let ch: Channel | null = null;
    
    const connectChannel = () => {
      const socket = PhoenixSocket.getSocket();
      
      if (!socket) {
        console.error('Socket not connected');
        return;
      }

      console.log(`Creating channel ${channelName}`);
      ch = socket.channel(channelName, params);
      
      ch.join()
        .receive("ok", (resp) => {
          console.log(`Successfully joined ${channelName}`, resp);
          setConnected(true);
        })
        .receive("error", ({ reason }) => {
          console.error(`Failed to join ${channelName}:`, reason);
          setConnected(false);
        })
        .receive("timeout", () => {
          console.error(`Timeout joining ${channelName}`);
          setConnected(false);
        });
      
      setChannel(ch);
    };
    
    // Small delay to ensure socket is connected
    const timer = setTimeout(connectChannel, 100);
    
    return () => {
      clearTimeout(timer);
      if (ch) {
        console.log(`Leaving channel ${channelName}`);
        ch.leave();
        setConnected(false);
      }
    };
  }, [channelName]); // Remove params from dependencies to avoid recreating channel
  
  return { channel, connected };
}