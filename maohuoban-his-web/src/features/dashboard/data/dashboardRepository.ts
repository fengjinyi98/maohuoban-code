import type { DashboardToday } from "../../../shared/api/types";
import { apiRequest } from "../../../shared/api/http";

export function getTodayDashboard() {
  return apiRequest<DashboardToday>("/api/mock/his/dashboard/today");
}
