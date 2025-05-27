import { useEffect, useState } from 'react';
import { Channel } from 'phoenix';
import PhoenixSocket from '~/modules/api/socket';

export function useChannel(channelName: string, params = {}) {
  const [channel, setChannel] = useState<Channel | null>(null);
  const [connected, setConnected] = useState(false);
  
  useEffect(() => {
    const socket = PhoenixSocket.getSocket();
    
    if (!socket) {
      console.error('Socket not connected');
      return;
    }

    const ch = socket.channel(channelName, params);
    
    ch.join()
      .receive("ok", () => {
        console.log(`Joined ${channelName}`);
        setConnected(true);
      })
      .receive("error", ({ reason }) => {
        console.error(`Failed to join ${channelName}:`, reason);
        setConnected(false);
      });
    
    setChannel(ch);
    
    return () => {
      if (ch) {
        ch.leave();
        setConnected(false);
      }
    };
  }, [channelName, params]);
  
  return { channel, connected };
}