import { useState } from "react";
import type { AuditAction } from "../../../shared/api/types";
import { HisPageShell } from "../../../shared/components/HisPageShell";
import { HisStatusChip } from "../../../shared/components/HisStatusChip";
import { auditActionLabels } from "../../../shared/utils/statusLabels";
import { useAuditViewModel } from "../view-models/useAuditViewModel";

const actions: Array<"" | AuditAction> = [
  "",
  "view",
  "edit",
  "export",
  "consent",
  "publish",
  "refund",
  "permission",
];

// AuditPage 授权审计页
// 核心职责：
// - 展示跨院、保险、家庭和平台工单授权
// - 支持访问、导出、发布、退款和权限变更日志筛选
export function AuditPage() {
  const [keyword, setKeyword] = useState("");
  const [action, setAction] = useState("");
  const vm = useAuditViewModel(keyword, action);

  return (
    <HisPageShell
      title="授权审计"
      description="证明谁在什么时间查看、导出、发布、退款或变更权限。"
    >
      <section
        className="mhb-card"
        style={{ display: "flex", gap: 10, flexWrap: "wrap" }}
      >
        <input
          className="mhb-input"
          placeholder="员工、宠物、目标、原因"
          value={keyword}
          onChange={(event) => setKeyword(event.target.value)}
        />
        <select
          className="mhb-input"
          value={action}
          onChange={(event) => setAction(event.target.value)}
        >
          {actions.map((item) => (
            <option key={item || "all"} value={item}>
              {item ? auditActionLabels[item] : "全部动作"}
            </option>
          ))}
        </select>
      </section>

      <section className="mhb-card">
        <h2 style={{ marginTop: 0 }}>授权记录</h2>
        <div className="mhb-grid mhb-grid-3">
          {vm.data?.consents.map((consent) => (
            <div className="mhb-card" key={consent.id}>
              <strong>{consent.patientName}</strong>
              <p>{consent.grantee}</p>
              <p style={{ color: "var(--mhb-muted)" }}>{consent.scope}</p>
              <HisStatusChip
                tone={consent.status === "active" ? "success" : "neutral"}
              >
                {consent.purpose} · {consent.expiresAt}
              </HisStatusChip>
            </div>
          ))}
        </div>
      </section>

      <section className="mhb-table-wrap">
        <table className="mhb-table">
          <thead>
            <tr>
              <th>时间</th>
              <th>操作人</th>
              <th>动作</th>
              <th>目标</th>
              <th>原因</th>
              <th>敏感</th>
            </tr>
          </thead>
          <tbody>
            {vm.data?.logs.map((log) => (
              <tr key={log.id}>
                <td>{log.createdAt}</td>
                <td>{log.actorName}</td>
                <td>
                  <HisStatusChip tone={log.sensitive ? "danger" : "info"}>
                    {auditActionLabels[log.action]}
                  </HisStatusChip>
                </td>
                <td>{log.target}</td>
                <td>{log.reason}</td>
                <td>{log.sensitive ? "是" : "否"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </HisPageShell>
  );
}
