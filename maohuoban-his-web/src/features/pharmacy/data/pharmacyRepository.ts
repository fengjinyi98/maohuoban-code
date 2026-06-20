import { apiRequest } from "../../../shared/api/http";
import { sessionHeaders } from "../../../shared/api/sessionHeaders";
import type { PharmacyBoard } from "../domain/models";

export function getPharmacyBoard() {
  return apiRequest<PharmacyBoard>("/api/mock/his/pharmacy");
}

export function dispenseEncounter(encounterId: string) {
  return apiRequest<PharmacyBoard>(
    `/api/mock/his/pharmacy/${encounterId}/dispense`,
    {
      method: "POST",
      headers: sessionHeaders(),
    },
  );
}
