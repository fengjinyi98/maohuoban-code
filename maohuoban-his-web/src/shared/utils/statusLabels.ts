import type {
  AuditAction,
  DispenseStatus,
  EncounterStatus,
  InvoiceStatus,
  PublicationStatus,
} from "../api/types";

export const encounterStatusLabels: Record<EncounterStatus, string> = {
  scheduled: "待到院",
  arrived: "已到院",
  triage: "待接诊",
  in_progress: "接诊中",
  pending_report: "待补报告",
  pending_billing: "待收费",
  pending_dispense: "待发药",
  completed: "已完成",
};

export const invoiceStatusLabels: Record<InvoiceStatus, string> = {
  unpaid: "未支付",
  paid: "已支付",
  refund_pending: "退款中",
  refunded: "已退款",
};

export const dispenseStatusLabels: Record<DispenseStatus, string> = {
  pending: "待发药",
  partial: "部分发药",
  dispensed: "已发药",
  returned: "已退药",
};

export const publicationStatusLabels: Record<PublicationStatus, string> = {
  pending: "待发布",
  published: "已发布",
  delayed: "延迟发布",
  blocked: "不发布",
};

export const auditActionLabels: Record<AuditAction, string> = {
  view: "查看",
  edit: "编辑",
  export: "导出",
  consent: "授权",
  publish: "发布",
  refund: "退款",
  permission: "权限变更",
};

// formatCurrency 金额格式化
// 核心职责：
// - 统一展示人民币金额
// - 避免页面重复拼接金额文案
export function formatCurrency(value: number) {
  return `¥${value.toFixed(2)}`;
}

// invoiceTotal 收费单金额汇总
// 核心职责：
// - 聚合项目和药品金额
// - 支撑收费页和测试校验
export function invoiceTotal(
  items: Array<{ quantity: number; unitPrice: number }>,
) {
  return items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
}
