import type { BackendEnvelope, PetPatient } from "../../../shared/api/types";
import { apiRequest, toJsonBody } from "../../../shared/api/http";
import { sessionHeaders } from "../../../shared/api/sessionHeaders";
import type { PatientDetail } from "../domain/models";

export function listPatients(keyword: string) {
  const params = keyword ? `?keyword=${encodeURIComponent(keyword)}` : "";
  return apiRequest<BackendEnvelope<PetPatient[]>>(
    `/api/v1/his/patients${params}`,
  ).then((response) => response.data);
}

export function getPatientDetail(patientId: string) {
  return apiRequest<BackendEnvelope<PatientDetail>>(
    `/api/v1/his/patients/${patientId}`,
  ).then((response) => response.data);
}

export function createPatient(
  patient: Omit<PetPatient, "id" | "medicalRecordNo" | "lastVisitAt">,
) {
  return apiRequest<BackendEnvelope<PetPatient>>("/api/v1/his/patients", {
    ...toJsonBody(patient),
    headers: sessionHeaders(),
  }).then((response) => response.data);
}
