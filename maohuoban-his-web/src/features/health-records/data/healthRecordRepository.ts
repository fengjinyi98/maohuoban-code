import type {
  BackendEnvelope,
  HealthRecordPublication,
} from "../../../shared/api/types";
import { apiRequest } from "../../../shared/api/http";
import { sessionHeaders } from "../../../shared/api/sessionHeaders";
import type { PublicationAction } from "../domain/models";

export function listPublications() {
  return apiRequest<BackendEnvelope<HealthRecordPublication[]>>(
    "/api/v1/his/health-record-publications",
  ).then((response) => response.data);
}

export function updatePublication(
  publicationId: string,
  action: PublicationAction,
) {
  return apiRequest<BackendEnvelope<HealthRecordPublication>>(
    `/api/v1/his/health-record-publications/${publicationId}/${action}`,
    {
      method: "POST",
      headers: sessionHeaders(),
    },
  ).then((response) => response.data);
}
