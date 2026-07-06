import { apiRequest } from "../../../shared/api/http";
import type { BackendEnvelope } from "../../../shared/api/types";
import type { SettingsBoard } from "../domain/models";

export function getSettingsBoard() {
  return apiRequest<BackendEnvelope<SettingsBoard>>(
    "/api/v1/his/settings",
  ).then((response) => response.data);
}
