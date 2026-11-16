import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { Presence, type Channel } from "phoenix";
import { debugLog } from "../config";
import PhoenixSocket from "../controllers/api/socket";

export interface UseChannelOptions {
  params?: Record<string, unknown>;
  enabled?: boolean;
}

export interface UseChannelResult {
  channel: Channel | null;
  connected: boolean;
  error: string | null;
  presences: PresenceEntry[] | null;
}

export interface PresenceEntry {
  key: string;
  metas: Record<string, unknown>[];
}

interface ChannelState extends UseChannelResult {
  socket: unknown;
  topic: string | null;
  paramsKey: string;
}

const noSocket = () => null;

const initialState: ChannelState = {
  socket: null,
  topic: null,
  paramsKey: "",
  channel: null,
  connected: false,
  error: null,
  presences: null,
};

/** Does not open the socket. Join each topic in one place: a second join on the same socket evicts the first. */
export function useChannel(topic: string | null | undefined, options: UseChannelOptions = {}): UseChannelResult {
  const { params, enabled = true } = options;
  const paramsKey = JSON.stringify(params ?? {});
  const socket = useSyncExternalStore(PhoenixSocket.subscribe, PhoenixSocket.getSocket, noSocket);
  const [state, setState] = useState<ChannelState>(initialState);

  useEffect(() => {
    if (!socket || !topic || !enabled) return;

    let active = true;
    const channel = socket.channel(topic, JSON.parse(paramsKey) as object);
    const update = (patch: Partial<UseChannelResult>) => {
      if (!active) return;
      setState((previous) => {
        const base =
          previous.socket === socket && previous.topic === topic && previous.paramsKey === paramsKey
            ? previous
            : { ...initialState, socket, topic, paramsKey };
        return { ...base, ...patch };
      });
    };

    // Bound before the join: the server pushes presence_state right after it.
    const presence = new Presence(channel);
    presence.onSync(() =>
      update({ presences: presence.list((key, { metas }: { metas: PresenceEntry["metas"] }) => ({ key, metas })) })
    );

    channel.onError(() => update({ connected: false }));
    channel.onClose(() => update({ connected: false }));

    channel
      .join()
      .receive("ok", () => {
        debugLog(`joined ${topic}`);
        update({ channel, connected: true, error: null });
      })
      .receive("error", (response: { reason?: string } | undefined) => {
        const reason = response?.reason ?? "join_failed";
        debugLog(`join of ${topic} refused:`, reason);
        update({ channel: null, connected: false, error: reason });
        // A refused join would be retried forever with the same answer.
        if (reason === "unauthorized") channel.leave();
      })
      .receive("timeout", () => {
        update({ connected: false });
      });

    return () => {
      active = false;
      debugLog(`leaving ${topic}`);
      channel.leave();
    };
  }, [socket, topic, enabled, paramsKey]);

  const current =
    enabled && state.socket === socket && state.topic === topic && state.paramsKey === paramsKey;

  return current
    ? { channel: state.channel, connected: state.connected, error: state.error, presences: state.presences }
    : { channel: null, connected: false, error: null, presences: null };
}

export function useChannelEvent<Payload = unknown>(
  channel: Channel | null,
  event: string,
  handler: (payload: Payload) => void
): void {
  const handlerRef = useRef(handler);

  useEffect(() => {
    handlerRef.current = handler;
  });

  useEffect(() => {
    if (!channel) return;
    const ref = channel.on(event, (payload: Payload) => handlerRef.current(payload));
    return () => {
      channel.off(event, ref);
    };
  }, [channel, event]);
}

export default useChannel;
