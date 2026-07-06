import { apiRequest } from "../../../shared/api/http";
import type { BackendEnvelope } from "../../../shared/api/types";
import type { AuditBoard } from "../domain/models";

export function getAuditBoard(keyword: string, action: string) {
  const params = new URLSearchParams();
  if (keyword) params.set("keyword", keyword);
  if (action) params.set("action", action);
  return apiRequest<BackendEnvelope<AuditBoard>>(
    `/api/v1/his/audit-logs?${params.toString()}`,
  ).then((response) => response.data);
}
