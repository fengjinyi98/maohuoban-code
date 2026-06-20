import type { PropsWithChildren } from "react";
import { Navigate, useLocation } from "react-router-dom";
import { readSession } from "./sessionStorage";

interface AuthGuardProps extends PropsWithChildren {
  requireContext?: boolean;
}

// AuthGuard 登录态路由保护
// 核心职责：
// - 阻止未登录用户访问后台
// - 要求医院和院区上下文完整后进入业务模块
export function AuthGuard({
  children,
  requireContext = false,
}: AuthGuardProps) {
  const location = useLocation();
  const session = readSession();

  if (!session) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }

  if (requireContext && (!session.tenant || !session.site)) {
    return <Navigate to="/select-context" replace />;
  }

  return children;
}
