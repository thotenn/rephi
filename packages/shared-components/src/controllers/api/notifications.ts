import type { ApiResponse, DashboardStats, RephiNotification } from "../../types";
import api from "./api";

const unwrap = <T>({ data }: { data: ApiResponse<T> }): T => data.data;

/** Needs `notifications:broadcast`. */
export function broadcastNotification(message: string): Promise<RephiNotification> {
  return api.post<ApiResponse<RephiNotification>>("/notifications/broadcast", { message }).then(unwrap);
}

/** Pushed only to the caller's own topic `user:<id>`; rate limited per user (429). */
export function sendTestNotification(message: string): Promise<RephiNotification> {
  return api.post<ApiResponse<RephiNotification>>("/notifications/me", { message }).then(unwrap);
}

export function fetchDashboard(): Promise<DashboardStats> {
  return api.get<ApiResponse<DashboardStats>>("/dashboard").then(unwrap);
}
