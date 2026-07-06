import { apiRequest } from "../../../shared/api/http";
import { sessionHeaders } from "../../../shared/api/sessionHeaders";
import type { BackendEnvelope } from "../../../shared/api/types";
import type { PharmacyBoard } from "../domain/models";

export function getPharmacyBoard() {
  return apiRequest<BackendEnvelope<PharmacyBoard>>(
    "/api/v1/his/pharmacy",
  ).then((response) => response.data);
}

export function dispenseEncounter(encounterId: string) {
  return apiRequest<BackendEnvelope<PharmacyBoard>>(
    `/api/v1/his/pharmacy/${encounterId}/dispense`,
    {
      method: "POST",
      headers: sessionHeaders(),
    },
  ).then((response) => response.data);
}
