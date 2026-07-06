import { queryOptions } from "@tanstack/react-query";
import { getTodayDashboard } from "../data/dashboardRepository";

// dashboardTodayQueryOptions 今日工作台查询策略
// 核心职责：
// - 统一今日工作台 queryKey 与请求函数
// - 让外部 App 预约变更后，Web HIS 聚焦时重新读取队列
export function dashboardTodayQueryOptions() {
  return queryOptions({
    queryKey: ["dashboard", "today"],
    queryFn: getTodayDashboard,
    staleTime: 0,
    refetchOnWindowFocus: "always",
    refetchInterval: 5000,
  });
}
