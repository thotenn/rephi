import { createContext, use } from "react";
import type { OnlineCounts } from "@rephi/shared-components";

export interface RealtimeState {
  /** Whether the broadcast channel (`user:lobby`) is joined right now. */
  connected: boolean;
  /** Who is on the lobby, from Phoenix Presence; `null` until the first presence state. */
  online: OnlineCounts | null;
}

export const RealtimeContext = createContext<RealtimeState>({ connected: false, online: null });

/** State of the app's realtime connection (see `RealtimeProvider`). */
export function useRealtime(): RealtimeState {
  return use(RealtimeContext);
}
