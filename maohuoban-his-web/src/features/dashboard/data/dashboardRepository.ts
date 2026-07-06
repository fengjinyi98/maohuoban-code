import type { BackendEnvelope, DashboardToday } from "../../../shared/api/types";
import { apiRequest } from "../../../shared/api/http";

export function getTodayDashboard() {
  return apiRequest<BackendEnvelope<DashboardToday>>(
    "/api/v1/his/dashboard/today",
  ).then((response) => response.data);
}
