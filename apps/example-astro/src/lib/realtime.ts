import { useSyncExternalStore } from "react";
import type { OnlineCounts } from "~/lib/rephi";

// Joined only by AppRuntime; other islands (separate React roots) read it from here.
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

export function useRealtimeConnected(): boolean {
  return useSyncExternalStore(subscribe, getConnected, getServerConnected);
}

export function useOnlineCounts(): OnlineCounts | null {
  return useSyncExternalStore(subscribe, getOnline, getServerOnline);
}
