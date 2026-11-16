import { createContext, use } from "react";

export interface RealtimeState {
  /** Whether the broadcast channel (`user:lobby`) is joined right now. */
  connected: boolean;
}

export const RealtimeContext = createContext<RealtimeState>({ connected: false });

/** State of the app's realtime connection (see `RealtimeProvider`). */
export function useRealtime(): RealtimeState {
  return use(RealtimeContext);
}
