import type {
  AuthSession,
  HospitalMember,
  HospitalSite,
  HospitalTenant,
} from "../../../shared/api/types";

export interface LoginResult {
  session: AuthSession;
  tenants: HospitalTenant[];
  sites: HospitalSite[];
  members: HospitalMember[];
}

export interface ContextOptions {
  tenants: HospitalTenant[];
  sites: HospitalSite[];
  members?: HospitalMember[];
}
