import { useQuery } from "@tanstack/react-query";
import { readSession } from "../../../shared/auth/sessionStorage";
import { dashboardTodayQueryOptions } from "./dashboardQueryOptions";

// useDashboardViewModel 今日工作台状态
// 核心职责：
// - 加载今日队列和风险提醒
// - 根据角色派生主待办
export function useDashboardViewModel() {
  const session = readSession();
  const query = useQuery(dashboardTodayQueryOptions());
  const role = session?.role ?? "doctor";
  const data = query.data;

  const roleTasks =
    role === "frontdesk"
      ? (data?.invoices.filter((item) => item.status === "unpaid") ?? [])
      : role === "pharmacy"
        ? (data?.encounters.filter(
            (item) => item.status === "pending_dispense",
          ) ?? [])
        : role === "doctor"
          ? (data?.encounters.filter((item) =>
              ["triage", "in_progress"].includes(item.status),
            ) ?? [])
          : (data?.encounters ?? []);

  return { ...query, role, roleTasks };
}
