import { useMutation, useQuery } from "@tanstack/react-query";
import type { Role } from "../../../shared/api/types";
import { readSession, writeSession } from "../../../shared/auth/sessionStorage";
import {
  getContextOptions,
  login,
  selectContext,
} from "../data/authRepository";

// useAuthViewModel 登录和上下文选择状态
// 核心职责：
// - 处理 mock 登录和 session 持久化
// - 处理医院、院区和角色选择
export function useAuthViewModel() {
  const loginMutation = useMutation({
    mutationFn: ({
      account,
      password,
    }: {
      account: string;
      password: string;
    }) => login(account, password),
    onSuccess: (result) => writeSession(result.session),
  });

  const contextMutation = useMutation({
    mutationFn: ({
      tenantId,
      siteId,
      role,
    }: {
      tenantId: string;
      siteId: string;
      role?: Role;
    }) => {
      const session = readSession();
      if (!session) {
        throw new Error("登录态已失效");
      }
      return selectContext(session, tenantId, siteId, role);
    },
    onSuccess: (session) => writeSession(session),
  });

  const contextOptionsQuery = useQuery({
    queryKey: ["auth", "context-options"],
    queryFn: getContextOptions,
  });

  return {
    loginMutation,
    contextMutation,
    contextOptionsQuery,
    session: readSession(),
  };
}
