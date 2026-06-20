import type { InventoryItem, VisitEncounter } from "../../../shared/api/types";

export interface PharmacyBoard {
  dispensing: VisitEncounter[];
  inventory: InventoryItem[];
}
