import type { AuditLog, ConsentGrant } from "../../../shared/api/types";

export interface AuditBoard {
  logs: AuditLog[];
  consents: ConsentGrant[];
}
