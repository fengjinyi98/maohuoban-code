import {
  ClipboardList,
  FileCheck2,
  FlaskConical,
  Monitor,
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
  icon: typeof Monitor;
}

export interface NavGroup {
  title: string;
  items: NavItem[];
}

export const navGroups: NavGroup[] = [
  {
    title: "工作台",
    items: [
      {
        path: "/dashboard",
        label: "今日接诊",
        permission: "dashboard.view",
        icon: Monitor,
      },
      {
        path: "/encounters/e-001",
        label: "快速接诊",
        permission: "encounters.view",
        icon: ClipboardList,
      },
    ],
  },
  {
    title: "医疗业务",
    items: [
      {
        path: "/encounters",
        label: "电子病历 EMR",
        permission: "encounters.view",
        icon: Stethoscope,
      },
      {
        path: "/pharmacy",
        label: "处方与发药",
        permission: "pharmacy.view",
        icon: Pill,
      },
      {
        path: "/health-records",
        label: "健康档案发布",
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
        path: "/encounters",
        label: "检查检验 LIS/PACS",
        permission: "encounters.view",
        icon: FlaskConical,
      },
    ],
  },
  {
    title: "医院运营",
    items: [
      {
        path: "/patients",
        label: "客户与患宠管理",
        permission: "patients.view",
        icon: Users,
      },
      {
        path: "/billing",
        label: "收费结算",
        permission: "billing.view",
        icon: ReceiptText,
      },
    ],
  },
  {
    title: "系统管理",
    items: [
      {
        path: "/settings",
        label: "员工与权限",
        permission: "settings.view",
        icon: Settings,
      },
    ],
  },
];
