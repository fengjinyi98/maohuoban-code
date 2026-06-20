import { Link } from "react-router-dom";
import {
  AlertTriangle,
  ArrowRight,
  Clock,
  FileCheck2,
  Pill,
  ReceiptText,
  Stethoscope,
} from "lucide-react";
import { HisPageShell } from "../../../shared/components/HisPageShell";
import { HisStatusChip } from "../../../shared/components/HisStatusChip";
import {
  encounterStatusLabels,
  invoiceStatusLabels,
  publicationStatusLabels,
} from "../../../shared/utils/statusLabels";
import { useDashboardViewModel } from "../view-models/useDashboardViewModel";

// DashboardPage 今日工作台
// 核心职责：
// - 展示今日概览、队列、角色待办和风险提醒
// - 提供到接诊、收费、药房和发布模块的快捷入口
export function DashboardPage() {
  const vm = useDashboardViewModel();

  if (vm.isLoading) {
    return (
      <HisPageShell title="今日工作台">
        <div className="mhb-card">加载今日队列...</div>
      </HisPageShell>
    );
  }

  if (!vm.data) {
    return (
      <HisPageShell title="今日工作台">
        <div className="mhb-card">今日数据加载失败</div>
      </HisPageShell>
    );
  }

  const summary = [
    { label: "今日预约", value: vm.data.summary.appointments, icon: Clock },
    {
      label: "待接诊",
      value: vm.data.summary.pendingEncounter,
      icon: Stethoscope,
    },
    {
      label: "待收费",
      value: vm.data.summary.pendingBilling,
      icon: ReceiptText,
    },
    { label: "待发药", value: vm.data.summary.pendingDispense, icon: Pill },
    {
      label: "待发布",
      value: vm.data.summary.pendingPublication,
      icon: FileCheck2,
    },
  ];

  return (
    <HisPageShell
      title="今日工作台"
      description="按角色聚合今日预约、接诊、收费、发药、发布和风险提醒。"
    >
      <div className="mhb-grid mhb-grid-5">
        {summary.map((item) => {
          const Icon = item.icon;
          return (
            <div className="mhb-card" key={item.label}>
              <Icon size={20} color="var(--mhb-primary)" />
              <div
                style={{
                  marginTop: 12,
                  color: "var(--mhb-muted)",
                  fontSize: 13,
                }}
              >
                {item.label}
              </div>
              <strong style={{ fontSize: 28 }}>{item.value}</strong>
            </div>
          );
        })}
      </div>

      <div className="mhb-grid mhb-grid-2">
        <section className="mhb-card">
          <h2 style={{ marginTop: 0 }}>角色主待办</h2>
          <div className="mhb-grid">
            {vm.roleTasks.map((task) =>
              "encounterId" in task ? null : (
                <Link
                  key={task.id}
                  to={
                    task.status === "pending_dispense"
                      ? "/pharmacy"
                      : `/encounters/${task.id}`
                  }
                  className="mhb-card"
                  style={{ padding: 12 }}
                >
                  <div
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      gap: 12,
                    }}
                  >
                    <strong>{task.patientName}</strong>
                    <HisStatusChip
                      tone={
                        task.status === "pending_dispense" ? "info" : "warning"
                      }
                    >
                      {encounterStatusLabels[task.status]}
                    </HisStatusChip>
                  </div>
                  <p style={{ margin: "6px 0 0", color: "var(--mhb-muted)" }}>
                    {task.chiefComplaint}
                  </p>
                </Link>
              ),
            )}
            {vm.roleTasks.length === 0 ? (
              <p style={{ color: "var(--mhb-muted)" }}>当前角色暂无待办。</p>
            ) : null}
          </div>
        </section>

        <section className="mhb-card">
          <h2 style={{ marginTop: 0 }}>风险提醒</h2>
          <div className="mhb-grid">
            {vm.data.inventoryRisks.map((item) => (
              <Link
                key={item.id}
                to="/pharmacy"
                className="mhb-card"
                style={{ padding: 12 }}
              >
                <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
                  <AlertTriangle size={18} color="var(--mhb-warning)" />
                  <strong>{item.name}</strong>
                  <HisStatusChip
                    tone={item.status === "low_stock" ? "danger" : "warning"}
                  >
                    {item.status === "low_stock" ? "低库存" : "近效期"}
                  </HisStatusChip>
                </div>
                <p style={{ margin: "6px 0 0", color: "var(--mhb-muted)" }}>
                  当前库存 {item.stock}
                  {item.unit}，阈值 {item.threshold}
                  {item.unit}
                </p>
              </Link>
            ))}
          </div>
        </section>
      </div>

      <section className="mhb-table-wrap">
        <table className="mhb-table">
          <thead>
            <tr>
              <th>时间</th>
              <th>宠物</th>
              <th>主人</th>
              <th>事项</th>
              <th>状态</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {vm.data.appointments.map((item) => (
              <tr key={item.id}>
                <td>{item.startsAt}</td>
                <td>{item.patientName}</td>
                <td>{item.ownerName}</td>
                <td>{item.reason}</td>
                <td>
                  <HisStatusChip
                    tone={item.status === "scheduled" ? "neutral" : "success"}
                  >
                    {item.status === "scheduled" ? "待到院" : "已到院"}
                  </HisStatusChip>
                </td>
                <td>
                  <Link
                    className="mhb-button secondary"
                    to={`/patients/${item.patientId}`}
                  >
                    查看 <ArrowRight size={14} />
                  </Link>
                </td>
              </tr>
            ))}
            {vm.data.invoices.map((item) => (
              <tr key={item.id}>
                <td>{item.createdAt.slice(11)}</td>
                <td>{item.patientName}</td>
                <td>{item.ownerName}</td>
                <td>收费单</td>
                <td>
                  <HisStatusChip
                    tone={item.status === "unpaid" ? "warning" : "success"}
                  >
                    {invoiceStatusLabels[item.status]}
                  </HisStatusChip>
                </td>
                <td>
                  <Link className="mhb-button secondary" to="/billing">
                    处理
                  </Link>
                </td>
              </tr>
            ))}
            {vm.data.publications.map((item) => (
              <tr key={item.id}>
                <td>待审核</td>
                <td>{item.patientName}</td>
                <td>-</td>
                <td>健康档案发布</td>
                <td>
                  <HisStatusChip
                    tone={item.status === "pending" ? "warning" : "info"}
                  >
                    {publicationStatusLabels[item.status]}
                  </HisStatusChip>
                </td>
                <td>
                  <Link className="mhb-button secondary" to="/health-records">
                    审核
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </HisPageShell>
  );
}
