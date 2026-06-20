import type { PetPatient } from "../../../shared/api/types";
import { apiRequest, toJsonBody } from "../../../shared/api/http";
import { sessionHeaders } from "../../../shared/api/sessionHeaders";
import type { PatientDetail } from "../domain/models";

export function listPatients(keyword: string) {
  const params = keyword ? `?keyword=${encodeURIComponent(keyword)}` : "";
  return apiRequest<PetPatient[]>(`/api/mock/his/patients${params}`);
}

export function getPatientDetail(patientId: string) {
  return apiRequest<PatientDetail>(`/api/mock/his/patients/${patientId}`);
}

export function createPatient(
  patient: Omit<PetPatient, "id" | "medicalRecordNo" | "lastVisitAt">,
) {
  return apiRequest<PetPatient>("/api/mock/his/patients", {
    ...toJsonBody(patient),
    headers: sessionHeaders(),
  });
}
