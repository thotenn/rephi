import { useSyncExternalStore } from "react";

/** Phoenix channel topics and events used by the app. */
export const channelsProps = {
  topics: {
    user: {
      lobby: "user:lobby",
    },
  },
  events: {
    user: {
      notification: "new_notification",
    },
  },
} as const;

/**
 * Connection state of the lobby channel.
 *
 * The channel is joined in exactly one place (the persisted `AppRuntime`
 * island). Other islands live in separate React roots, so they read the state
 * from this module-level store instead of joining the topic a second time.
 */
let connected = false;
const listeners = new Set<() => void>();

export function setRealtimeConnected(next: boolean): void {
  if (connected === next) return;
  connected = next;
  listeners.forEach((listener) => listener());
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

const getSnapshot = () => connected;
const getServerSnapshot = () => false;

/** Whether the lobby channel is currently joined. */
export function useRealtimeConnected(): boolean {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}
