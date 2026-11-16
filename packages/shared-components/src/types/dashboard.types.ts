/** Who is on the lobby right now: distinct users and their sockets. */
export interface OnlineCounts {
  online_users: number;
  connections: number;
}

/** `GET /api/dashboard`. A counter the caller may not see is `null`. */
export interface DashboardStats {
  users: { total: number | null };
  notifications: { sent_total: number | null; sent_by_me: number };
  sessions: OnlineCounts;
}
