import type { ApiResponse, DashboardStats, RephiNotification } from "../../types";
import api from "./api";

const unwrap = <T>({ data }: { data: ApiResponse<T> }): T => data.data;

export function broadcastNotification(message: string): Promise<RephiNotification> {
  return api.post<ApiResponse<RephiNotification>>("/notifications/broadcast", { message }).then(unwrap);
}

export function sendTestNotification(message: string): Promise<RephiNotification> {
  return api.post<ApiResponse<RephiNotification>>("/notifications/me", { message }).then(unwrap);
}

export function fetchDashboard(): Promise<DashboardStats> {
  return api.get<ApiResponse<DashboardStats>>("/dashboard").then(unwrap);
}
