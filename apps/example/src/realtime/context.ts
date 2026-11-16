import { createContext, use } from "react";
import type { OnlineCounts } from "@rephi/shared-components";

export interface RealtimeState {
  connected: boolean;
  online: OnlineCounts | null;
}

export const RealtimeContext = createContext<RealtimeState>({ connected: false, online: null });

export function useRealtime(): RealtimeState {
  return use(RealtimeContext);
}
