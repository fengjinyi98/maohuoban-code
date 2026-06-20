import type { VisitEncounter } from "../../../shared/api/types";
import { apiRequest, toJsonBody } from "../../../shared/api/http";
import { sessionHeaders } from "../../../shared/api/sessionHeaders";

export function listEncounters() {
  return apiRequest<VisitEncounter[]>("/api/mock/his/encounters");
}

export function getEncounter(encounterId: string) {
  return apiRequest<VisitEncounter>(`/api/mock/his/encounters/${encounterId}`);
}

export function startEncounter(encounterId: string) {
  return apiRequest<VisitEncounter>(
    `/api/mock/his/encounters/${encounterId}/start`,
    {
      method: "POST",
      headers: sessionHeaders(),
    },
  );
}

export function saveEncounter(
  encounterId: string,
  payload: Partial<VisitEncounter>,
) {
  return apiRequest<VisitEncounter>(
    `/api/mock/his/encounters/${encounterId}/save`,
    {
      ...toJsonBody(payload),
      headers: sessionHeaders(),
    },
  );
}
