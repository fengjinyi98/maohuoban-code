import { apiRequest } from "../../../shared/api/http";
import type { AuditBoard } from "../domain/models";

export function getAuditBoard(keyword: string, action: string) {
  const params = new URLSearchParams();
  if (keyword) params.set("keyword", keyword);
  if (action) params.set("action", action);
  return apiRequest<AuditBoard>(
    `/api/mock/his/audit-logs?${params.toString()}`,
  );
}
