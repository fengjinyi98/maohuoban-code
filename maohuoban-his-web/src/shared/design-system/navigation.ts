import {
  ClipboardList,
  FileCheck2,
  LayoutDashboard,
  Pill,
  ReceiptText,
  Settings,
  ShieldCheck,
  Stethoscope,
  Users,
} from "lucide-react";
import type { Permission } from "../api/types";

export interface NavItem {
  path: string;
  label: string;
  permission: Permission;
  icon: typeof LayoutDashboard;
}

export const navItems: NavItem[] = [
  {
    path: "/dashboard",
    label: "今日工作台",
    permission: "dashboard.view",
    icon: LayoutDashboard,
  },
  {
    path: "/patients",
    label: "宠物患者",
    permission: "patients.view",
    icon: Users,
  },
  {
    path: "/encounters",
    label: "接诊病历",
    permission: "encounters.view",
    icon: Stethoscope,
  },
  {
    path: "/billing",
    label: "收费",
    permission: "billing.view",
    icon: ReceiptText,
  },
  {
    path: "/pharmacy",
    label: "药房库存",
    permission: "pharmacy.view",
    icon: Pill,
  },
  {
    path: "/health-records",
    label: "健康档案",
    permission: "healthRecords.view",
    icon: FileCheck2,
  },
  {
    path: "/audit",
    label: "授权审计",
    permission: "audit.view",
    icon: ShieldCheck,
  },
  {
    path: "/settings",
    label: "设置",
    permission: "settings.view",
    icon: Settings,
  },
  {
    path: "/encounters/e-001",
    label: "快速接诊",
    permission: "encounters.view",
    icon: ClipboardList,
  },
];
