import type { BackendEnvelope, VisitEncounter } from "../../../shared/api/types";
import { apiRequest, toJsonBody } from "../../../shared/api/http";
import { sessionHeaders } from "../../../shared/api/sessionHeaders";

export function listEncounters() {
  return apiRequest<BackendEnvelope<VisitEncounter[]>>(
    "/api/v1/his/encounters",
  ).then((response) => response.data);
}

export function getEncounter(encounterId: string) {
  return apiRequest<BackendEnvelope<VisitEncounter>>(
    `/api/v1/his/encounters/${encounterId}`,
  ).then((response) => response.data);
}

export function startEncounter(encounterId: string) {
  return apiRequest<BackendEnvelope<VisitEncounter>>(
    `/api/v1/his/encounters/${encounterId}/start`,
    {
      method: "POST",
      headers: sessionHeaders(),
    },
  ).then((response) => response.data);
}

export function saveEncounter(
  encounterId: string,
  payload: Partial<VisitEncounter>,
) {
  return apiRequest<BackendEnvelope<VisitEncounter>>(
    `/api/v1/his/encounters/${encounterId}/save`,
    {
      ...toJsonBody(payload),
      headers: sessionHeaders(),
    },
  ).then((response) => response.data);
}
