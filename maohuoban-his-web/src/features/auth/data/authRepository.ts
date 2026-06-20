import type { AuthSession, Role } from "../../../shared/api/types";
import { apiRequest, toJsonBody } from "../../../shared/api/http";
import type { ContextOptions, LoginResult } from "../domain/models";

export function login(account: string, password: string) {
  return apiRequest<LoginResult>(
    "/api/mock/auth/login",
    toJsonBody({ account, password }),
  );
}

export function selectContext(
  session: AuthSession,
  tenantId: string,
  siteId: string,
  role?: Role,
) {
  return apiRequest<AuthSession>(
    "/api/mock/auth/context",
    toJsonBody({ session, tenantId, siteId, role }),
  );
}

export function getContextOptions() {
  return apiRequest<ContextOptions>("/api/mock/auth/context-options");
}
