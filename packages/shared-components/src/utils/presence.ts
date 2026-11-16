import type { OnlineCounts } from "../types";
import type { PresenceEntry } from "../hooks/useChannel";

export function presenceCounts(presences: PresenceEntry[] | null): OnlineCounts | null {
  if (!presences) return null;
  return {
    online_users: presences.length,
    connections: presences.reduce((sum, entry) => sum + entry.metas.length, 0),
  };
}
