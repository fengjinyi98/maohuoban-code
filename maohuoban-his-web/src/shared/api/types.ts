export type Role =
  | "owner"
  | "doctor"
  | "assistant"
  | "frontdesk"
  | "pharmacy"
  | "finance"
  | "admin";

export type Permission =
  | "dashboard.view"
  | "patients.view"
  | "patients.create"
  | "encounters.view"
  | "encounters.edit"
  | "prescriptions.create"
  | "billing.view"
  | "billing.charge"
  | "billing.refund"
  | "pharmacy.view"
  | "pharmacy.dispense"
  | "inventory.manage"
  | "healthRecords.view"
  | "healthRecords.publish"
  | "audit.view"
  | "settings.view"
  | "staff.manage";

export type EncounterStatus =
  | "scheduled"
  | "arrived"
  | "triage"
  | "in_progress"
  | "pending_report"
  | "pending_billing"
  | "pending_dispense"
  | "completed";

export type InvoiceStatus = "unpaid" | "paid" | "refund_pending" | "refunded";
export type DispenseStatus = "pending" | "partial" | "dispensed" | "returned";
export type PublicationStatus = "pending" | "published" | "delayed" | "blocked";
export type AuditAction =
  | "view"
  | "edit"
  | "export"
  | "consent"
  | "publish"
  | "refund"
  | "permission";

export interface HospitalTenant {
  id: string;
  name: string;
  tier: "standard_saas" | "dedicated_tenant";
}

export interface HospitalSite {
  id: string;
  tenantId: string;
  name: string;
  city: string;
}

export interface HospitalMember {
  id: string;
  tenantId: string;
  siteIds: string[];
  name: string;
  account: string;
  role: Role;
  enabled: boolean;
}

export interface AuthSession {
  member: HospitalMember;
  tenant?: HospitalTenant;
  site?: HospitalSite;
  role: Role;
  accessToken?: string;
  refreshToken?: string;
}

export interface OwnerProfile {
  id: string;
  name: string;
  phone: string;
}

export interface PetPatient {
  id: string;
  medicalRecordNo: string;
  name: string;
  species: "猫" | "狗";
  breed: string;
  ageText: string;
  sex: string;
  weightKg: number;
  ownerId: string;
  ownerName: string;
  ownerPhone: string;
  allergies: string[];
  chronicDiseases: string[];
  currentMedications: string[];
  lastVisitAt: string;
  notes: string;
}

export interface Appointment {
  id: string;
  patientId: string;
  patientName: string;
  ownerName: string;
  startsAt: string;
  reason: string;
  status: "scheduled" | "arrived" | "no_show" | "cancelled";
}

export interface PrescriptionItem {
  id: string;
  inventoryItemId: string;
  name: string;
  dosage: string;
  frequency: string;
  route: string;
  days: number;
  quantity: number;
  unitPrice: number;
}

export interface VisitEncounter {
  id: string;
  patientId: string;
  patientName: string;
  ownerName: string;
  doctorId: string;
  doctorName: string;
  status: EncounterStatus;
  chiefComplaint: string;
  diagnosis: string;
  vitals: {
    weightKg: number;
    temperatureC: number;
    heartRate: number;
    respiration: number;
    appetite: string;
    spirit: string;
  };
  orders: string[];
  prescriptionItems: PrescriptionItem[];
  internalNote: string;
  followUpAdvice: string;
  updatedAt: string;
}

export interface InvoiceItem {
  id: string;
  name: string;
  type: "service" | "drug" | "lab" | "imaging";
  quantity: number;
  unitPrice: number;
}

export interface Invoice {
  id: string;
  encounterId: string;
  patientName: string;
  ownerName: string;
  status: InvoiceStatus;
  paymentMethod?: "cash" | "wechat" | "alipay" | "card";
  items: InvoiceItem[];
  refundReason?: string;
  createdAt: string;
}

export interface InventoryBatch {
  id: string;
  batchNo: string;
  expiresAt: string;
  stock: number;
}

export interface InventoryItem {
  id: string;
  name: string;
  specification: string;
  unit: string;
  stock: number;
  threshold: number;
  status: "normal" | "low_stock" | "near_expiry" | "disabled";
  batches: InventoryBatch[];
}

export interface HealthRecordPublication {
  id: string;
  encounterId: string;
  patientName: string;
  diagnosisSummary: string;
  medicationSummary: string;
  reportSummary: string;
  followUpAdvice: string;
  status: PublicationStatus;
  version: number;
  publishedAt?: string;
  publishedBy?: string;
}

export interface ConsentGrant {
  id: string;
  patientName: string;
  grantee: string;
  scope: string;
  purpose: "跨院复诊" | "保险理赔" | "家庭共管" | "平台工单";
  expiresAt: string;
  status: "active" | "expired" | "revoked";
}

export interface AuditLog {
  id: string;
  actorName: string;
  actorRole: Role;
  action: AuditAction;
  target: string;
  reason: string;
  createdAt: string;
  sensitive: boolean;
}

export interface DashboardToday {
  summary: {
    appointments: number;
    pendingEncounter: number;
    pendingBilling: number;
    pendingDispense: number;
    pendingPublication: number;
  };
  appointments: Appointment[];
  encounters: VisitEncounter[];
  invoices: Invoice[];
  inventoryRisks: InventoryItem[];
  publications: HealthRecordPublication[];
}

export interface ApiErrorPayload {
  code: string;
  message: string;
}

export interface BackendEnvelope<T> {
  success: boolean;
  code: string;
  message: string;
  data: T;
}
