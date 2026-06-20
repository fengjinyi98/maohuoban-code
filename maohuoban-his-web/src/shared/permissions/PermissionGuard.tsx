import type { PropsWithChildren } from "react";
import type { Permission } from "../api/types";
import { readSession } from "../auth/sessionStorage";
import { ForbiddenPage } from "../components/ForbiddenPage";
import { hasPermission } from "./permissions";

interface PermissionGuardProps extends PropsWithChildren {
  permission: Permission;
}

// PermissionGuard 权限路由保护
// 核心职责：
// - 根据当前角色控制页面入口
// - 让无权限访问展示 403
export function PermissionGuard({
  children,
  permission,
}: PermissionGuardProps) {
  const session = readSession();

  if (!session || !hasPermission(session.role, permission)) {
    return <ForbiddenPage />;
  }

  return children;
}
