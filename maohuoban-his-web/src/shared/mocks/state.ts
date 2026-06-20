import type {
  AuditLog,
  AuthSession,
  HealthRecordPublication,
  InventoryItem,
  Invoice,
  PetPatient,
  VisitEncounter,
} from "../api/types";
import {
  auditLogs,
  consents,
  encounters,
  inventory,
  invoices,
  members,
  patients,
  publications,
  sites,
  tenants,
} from "./fixtures";

export const mockState = {
  tenants: structuredClone(tenants),
  sites: structuredClone(sites),
  members: structuredClone(members),
  patients: structuredClone(patients) as PetPatient[],
  encounters: structuredClone(encounters) as VisitEncounter[],
  invoices: structuredClone(invoices) as Invoice[],
  inventory: structuredClone(inventory) as InventoryItem[],
  publications: structuredClone(publications) as HealthRecordPublication[],
  consents: structuredClone(consents),
  auditLogs: structuredClone(auditLogs) as AuditLog[],
};

// addAudit 写入 mock 审计日志
// 核心职责：
// - 为敏感操作生成可筛选记录
// - 保持审计到人和原因字段
export function addAudit(
  session: AuthSession | null,
  action: AuditLog["action"],
  target: string,
  reason: string,
  sensitive = true,
) {
  mockState.auditLogs.unshift({
    id: `a-${Date.now()}`,
    actorName: session?.member.name ?? "mock 系统",
    actorRole: session?.role ?? "owner",
    action,
    target,
    reason,
    createdAt: new Date().toLocaleString("zh-CN", { hour12: false }),
    sensitive,
  });
}

// parseSessionHeader 解析 mock session
// 核心职责：
// - 从请求头恢复当前操作人
// - 支撑审计记录归属
export function parseSessionHeader(request: Request): AuthSession | null {
  const raw = request.headers.get("x-mhb-session");
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(decodeURIComponent(raw)) as AuthSession;
  } catch {
    return null;
  }
}
