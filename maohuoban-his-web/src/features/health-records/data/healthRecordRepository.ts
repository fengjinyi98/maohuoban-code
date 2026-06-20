import type { HealthRecordPublication } from "../../../shared/api/types";
import { apiRequest } from "../../../shared/api/http";
import { sessionHeaders } from "../../../shared/api/sessionHeaders";
import type { PublicationAction } from "../domain/models";

export function listPublications() {
  return apiRequest<HealthRecordPublication[]>(
    "/api/mock/his/health-record-publications",
  );
}

export function updatePublication(
  publicationId: string,
  action: PublicationAction,
) {
  return apiRequest<HealthRecordPublication>(
    `/api/mock/his/health-record-publications/${publicationId}/${action}`,
    {
      method: "POST",
      headers: sessionHeaders(),
    },
  );
}
