import { useSyncExternalStore } from "react";
import type { OnlineCounts } from "~/lib/rephi";

/**
 * State of the lobby channel.
 *
 * The channel is joined in exactly one place (the persisted `AppRuntime`
 * island). Other islands live in separate React roots, so they read the state
 * from this module-level store instead of joining the topic a second time.
 */
let connected = false;
let online: OnlineCounts | null = null;
const listeners = new Set<() => void>();

const notify = () => listeners.forEach((listener) => listener());

export function setRealtimeConnected(next: boolean): void {
  if (connected === next) return;
  connected = next;
  notify();
}

export function setOnlineCounts(next: OnlineCounts | null): void {
  if (online === next) return;
  online = next;
  notify();
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

const getConnected = () => connected;
const getOnline = () => online;
const getServerConnected = () => false;
const getServerOnline = () => null;

/** Whether the lobby channel is currently joined. */
export function useRealtimeConnected(): boolean {
  return useSyncExternalStore(subscribe, getConnected, getServerConnected);
}

/** Who is on the lobby (Phoenix Presence); `null` until the first presence state. */
export function useOnlineCounts(): OnlineCounts | null {
  return useSyncExternalStore(subscribe, getOnline, getServerOnline);
}
