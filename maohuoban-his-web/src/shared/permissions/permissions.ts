import type { Permission, Role } from "../api/types";

export const roleLabels: Record<Role, string> = {
  owner: "院长",
  doctor: "医生",
  assistant: "助理",
  frontdesk: "前台",
  pharmacy: "药房",
  finance: "财务",
  admin: "管理员",
};

export const rolePermissions: Record<Role, Permission[]> = {
  owner: [
    "dashboard.view",
    "patients.view",
    "patients.create",
    "encounters.view",
    "encounters.edit",
    "prescriptions.create",
    "billing.view",
    "billing.charge",
    "billing.refund",
    "pharmacy.view",
    "pharmacy.dispense",
    "inventory.manage",
    "healthRecords.view",
    "healthRecords.publish",
    "audit.view",
    "settings.view",
    "staff.manage",
  ],
  doctor: [
    "dashboard.view",
    "patients.view",
    "patients.create",
    "encounters.view",
    "encounters.edit",
    "prescriptions.create",
    "healthRecords.view",
    "healthRecords.publish",
  ],
  assistant: [
    "dashboard.view",
    "patients.view",
    "patients.create",
    "encounters.view",
  ],
  frontdesk: [
    "dashboard.view",
    "patients.view",
    "patients.create",
    "billing.view",
    "billing.charge",
    "billing.refund",
  ],
  pharmacy: [
    "dashboard.view",
    "pharmacy.view",
    "pharmacy.dispense",
    "inventory.manage",
  ],
  finance: [
    "dashboard.view",
    "billing.view",
    "billing.charge",
    "billing.refund",
    "audit.view",
  ],
  admin: [
    "dashboard.view",
    "patients.view",
    "patients.create",
    "encounters.view",
    "encounters.edit",
    "prescriptions.create",
    "billing.view",
    "billing.charge",
    "billing.refund",
    "pharmacy.view",
    "pharmacy.dispense",
    "inventory.manage",
    "healthRecords.view",
    "healthRecords.publish",
    "audit.view",
    "settings.view",
    "staff.manage",
  ],
};

// hasPermission 角色权限判断
// 核心职责：
// - 将前端体验权限集中到纯函数
// - 支撑导航、按钮和路由 guard
export function hasPermission(role: Role, permission: Permission) {
  return rolePermissions[role].includes(permission);
}
