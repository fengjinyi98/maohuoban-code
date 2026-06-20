import type { ReactNode } from "react";

type ChipTone = "neutral" | "success" | "warning" | "danger" | "info";

interface HisStatusChipProps {
  children: ReactNode;
  tone?: ChipTone;
}

// HisStatusChip HIS 状态标签
// 核心职责：
// - 统一展示就诊、收费、发药、发布和审计状态
// - 让风险类状态保持醒目
export function HisStatusChip({
  children,
  tone = "neutral",
}: HisStatusChipProps) {
  return <span className={`mhb-chip ${tone}`}>{children}</span>;
}
