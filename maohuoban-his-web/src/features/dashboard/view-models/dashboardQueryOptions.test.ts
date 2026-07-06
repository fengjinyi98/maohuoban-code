import { describe, expect, it } from "vitest";
import { dashboardTodayQueryOptions } from "./dashboardQueryOptions";

// dashboardQueryOptions 今日工作台查询策略测试
// 核心职责：
// - 固化跨端预约变更后的刷新策略
// - 避免 App 创建或取消预约后 Web HIS 继续展示旧队列
describe("dashboardTodayQueryOptions", () => {
  it("refetches when the HIS window receives focus even inside global stale time", () => {
    const options = dashboardTodayQueryOptions();

    expect(options.queryKey).toEqual(["dashboard", "today"]);
    expect(options.staleTime).toBe(0);
    expect(options.refetchOnWindowFocus).toBe("always");
    expect(options.refetchInterval).toBe(5000);
  });
});
