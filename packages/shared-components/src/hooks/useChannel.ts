import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import type { Channel } from "phoenix";
import { debugLog } from "../config";
import PhoenixSocket from "../controllers/api/socket";

export interface UseChannelOptions {
  /** Join params. A change (by value) leaves the channel and joins again. */
  params?: Record<string, unknown>;
  /** `false` keeps the channel left (e.g. until the user is known). Default `true`. */
  enabled?: boolean;
}

export interface UseChannelResult {
  /** The joined channel, or `null` until the join succeeds. */
  channel: Channel | null;
  /** True while the channel is joined; false while the socket is down or rejoining. */
  connected: boolean;
  /** The `reason` of a refused join (e.g. `"unauthorized"`), which is not retried. */
  error: string | null;
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
};

/**
 * Joins `topic` on the shared socket (`PhoenixSocket`) while the component is
 * mounted, and leaves it on unmount or when `topic` / `params` change.
 *
 * It does not open the socket: whoever owns the session calls
 * `PhoenixSocket.connect()`. The channel is joined as soon as a socket exists
 * (Phoenix queues the join until the socket opens) and is rejoined by Phoenix
 * after a reconnect, which flips `connected` back to true.
 *
 * Join each topic in one place only: Phoenix allows a single subscription per
 * topic and socket, and a second join evicts the first one.
 */
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
        // Phoenix retries the join on its own.
        update({ connected: false });
      });

    return () => {
      active = false;
      debugLog(`leaving ${topic}`);
      channel.leave();
    };
  }, [socket, topic, enabled, paramsKey]);

  // State left over from another socket / topic / params is not this one's.
  const current =
    enabled && state.socket === socket && state.topic === topic && state.paramsKey === paramsKey;

  return current
    ? { channel: state.channel, connected: state.connected, error: state.error }
    : { channel: null, connected: false, error: null };
}

/**
 * Calls `handler` for every `event` pushed on `channel` (as returned by
 * `useChannel`). The latest `handler` is always used, without re-binding.
 */
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
