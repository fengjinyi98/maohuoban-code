import type {
  Invoice,
  PetPatient,
  VisitEncounter,
} from "../../../shared/api/types";

export interface PatientDetail {
  patient: PetPatient;
  encounters: VisitEncounter[];
  invoices: Invoice[];
}
