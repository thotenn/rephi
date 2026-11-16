export interface OnlineCounts {
  online_users: number;
  connections: number;
}

export interface DashboardStats {
  users: { total: number | null };
  notifications: { sent_total: number | null; sent_by_me: number };
  sessions: OnlineCounts;
}
