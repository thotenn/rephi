import { useEffect, useState } from 'react';
import { Channel } from 'phoenix';
import socket from '~/modules/api/socket';

export function useChannel(channelName: string) {
  const [channel, setChannel] = useState<Channel | null>(null);
  
  useEffect(() => {
    const ch = socket.channel(channelName, {});
    
    ch.join()
      .receive("ok", () => console.log(`Joined ${channelName}`))
      .receive("error", () => console.log(`Failed to join ${channelName}`));
    
    setChannel(ch);
    
    return () => {
      ch.leave();
    };
  }, [channelName]);
  
  return channel;
}