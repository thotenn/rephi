import { useEffect, useState, useRef, useCallback } from 'react';
import { Channel } from 'phoenix';
import { usePhoenix } from '@/components/PhoenixProvider';

interface UseChannelOptions {
  onJoin?: () => void;
  onError?: (error: any) => void;
  onClose?: () => void;
}

export const useChannel = (
  topic: string,
  params: object = {},
  options: UseChannelOptions = {}
) => {
  const { channel: createChannel, connected } = usePhoenix();
  const [channel, setChannel] = useState<Channel | null>(null);
  const [joined, setJoined] = useState(false);
  const channelRef = useRef<Channel | null>(null);

  const join = useCallback(() => {
    if (!connected || channelRef.current) return;

    const newChannel = createChannel(topic, params);
    if (!newChannel) return;

    channelRef.current = newChannel;
    setChannel(newChannel);

    newChannel
      .join()
      .receive('ok', () => {
        console.log(`Joined channel: ${topic}`);
        setJoined(true);
        options.onJoin?.();
      })
      .receive('error', (resp) => {
        console.error(`Failed to join channel: ${topic}`, resp);
        options.onError?.(resp);
      });

    newChannel.onClose(() => {
      console.log(`Channel closed: ${topic}`);
      setJoined(false);
      options.onClose?.();
    });
  }, [connected, topic, JSON.stringify(params)]);

  const leave = useCallback(() => {
    if (channelRef.current) {
      channelRef.current.leave();
      channelRef.current = null;
      setChannel(null);
      setJoined(false);
    }
  }, []);

  const push = useCallback((event: string, payload: object = {}) => {
    if (!channelRef.current || !joined) {
      console.warn(`Cannot push to channel ${topic}: not joined`);
      return null;
    }
    return channelRef.current.push(event, payload);
  }, [joined, topic]);

  const on = useCallback((event: string, callback: (payload: any) => void) => {
    if (!channelRef.current) {
      console.warn(`Cannot listen to channel ${topic}: not created`);
      return () => {};
    }

    const ref = channelRef.current.on(event, callback);
    return () => channelRef.current?.off(event, ref);
  }, [topic]);

  useEffect(() => {
    if (connected) {
      join();
    }

    return () => {
      leave();
    };
  }, [connected, join]);

  return {
    channel,
    joined,
    join,
    leave,
    push,
    on
  };
};
