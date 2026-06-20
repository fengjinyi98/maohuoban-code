import type {
  HospitalMember,
  HospitalSite,
  InventoryItem,
  Role,
} from "../../../shared/api/types";

export interface SettingsBoard {
  members: HospitalMember[];
  sites: HospitalSite[];
  inventory: InventoryItem[];
  roles: Role[];
}
