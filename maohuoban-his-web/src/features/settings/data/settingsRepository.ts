import { apiRequest } from "../../../shared/api/http";
import type { SettingsBoard } from "../domain/models";

export function getSettingsBoard() {
  return apiRequest<SettingsBoard>("/api/mock/his/settings");
}
