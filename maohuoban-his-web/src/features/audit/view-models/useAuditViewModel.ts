import { useQuery } from "@tanstack/react-query";
import { getAuditBoard } from "../data/auditRepository";

// useAuditViewModel 授权审计状态
// 核心职责：
// - 加载授权记录和访问日志
// - 支持员工、宠物、动作和原因筛选
export function useAuditViewModel(keyword: string, action: string) {
  return useQuery({
    queryKey: ["audit", keyword, action],
    queryFn: () => getAuditBoard(keyword, action),
  });
}
