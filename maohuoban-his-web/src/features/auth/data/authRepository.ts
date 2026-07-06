import type {
  AuthSession,
  BackendEnvelope,
  Role,
} from "../../../shared/api/types";
import { apiRequest, toJsonBody } from "../../../shared/api/http";
import type { ContextOptions, LoginResult } from "../domain/models";

interface PasswordLoginData {
  access_token: string;
  refresh_token: string;
  user: {
    id: string;
    phone: string;
  };
}

export async function login(account: string, password: string) {
  const loginEnvelope = await apiRequest<BackendEnvelope<PasswordLoginData>>(
    "/api/v1/auth/password/login",
    toJsonBody({
      phone: account,
      password,
      device: {
        device_id: "web-his-browser",
        device_name: "Web HIS",
        platform: "Web",
        app_version: "1.0",
      },
    }),
  );
  window.localStorage.setItem(
    "maohuoban.webHis.accessToken",
    loginEnvelope.data.access_token,
  );
  const options = await getContextOptions();
  const member = options.members?.[0];
  if (!member) {
    throw new Error("当前账号未绑定 HIS 员工身份");
  }
  return {
    session: {
      member,
      role: member.role,
      accessToken: loginEnvelope.data.access_token,
      refreshToken: loginEnvelope.data.refresh_token,
    },
    tenants: options.tenants,
    sites: options.sites,
    members: options.members ?? [],
  } satisfies LoginResult;
}

export function selectContext(
  session: AuthSession,
  tenantId: string,
  siteId: string,
  role?: Role,
) {
  return apiRequest<BackendEnvelope<AuthSession>>(
    "/api/v1/his/session/context",
    toJsonBody({ session, tenantId, siteId, role }),
  ).then((response) => ({
    ...response.data,
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
  }));
}

export function getContextOptions() {
  return apiRequest<BackendEnvelope<ContextOptions>>(
    "/api/v1/his/session/context-options",
  ).then((response) => response.data);
}
