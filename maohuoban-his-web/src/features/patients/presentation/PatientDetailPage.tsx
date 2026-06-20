import { Link, useParams } from "react-router-dom";
import { HisPageShell } from "../../../shared/components/HisPageShell";
import { HisStatusChip } from "../../../shared/components/HisStatusChip";
import {
  encounterStatusLabels,
  invoiceStatusLabels,
} from "../../../shared/utils/statusLabels";
import { usePatientDetailViewModel } from "../view-models/usePatientDetailViewModel";

// PatientDetailPage 患者详情页
// 核心职责：
// - 展示宠物基础信息、主人信息和健康概览
// - 提供历史就诊到接诊详情的跳转
export function PatientDetailPage() {
  const { patientId = "" } = useParams();
  const vm = usePatientDetailViewModel(patientId);

  if (vm.isLoading) {
    return (
      <HisPageShell title="患者详情">
        <div className="mhb-card">加载患者详情...</div>
      </HisPageShell>
    );
  }

  if (!vm.data) {
    return (
      <HisPageShell title="患者详情">
        <div className="mhb-card">患者不存在</div>
      </HisPageShell>
    );
  }

  const { patient } = vm.data;

  return (
    <HisPageShell
      title={`${patient.name} · 患者详情`}
      description={`${patient.ownerName} ${patient.ownerPhone}`}
    >
      <div className="mhb-grid mhb-grid-3">
        <section className="mhb-card">
          <h2 style={{ marginTop: 0 }}>基础信息</h2>
          <p>
            {patient.species} · {patient.breed} · {patient.ageText}
          </p>
          <p>
            {patient.sex} · {patient.weightKg}kg
          </p>
          <p style={{ color: "var(--mhb-muted)" }}>{patient.notes}</p>
        </section>
        <section className="mhb-card">
          <h2 style={{ marginTop: 0 }}>风险信息</h2>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
            {patient.allergies.map((item) => (
              <HisStatusChip key={item} tone="danger">
                {item}
              </HisStatusChip>
            ))}
            {patient.chronicDiseases.map((item) => (
              <HisStatusChip key={item} tone="warning">
                {item}
              </HisStatusChip>
            ))}
            {patient.currentMedications.map((item) => (
              <HisStatusChip key={item} tone="info">
                {item}
              </HisStatusChip>
            ))}
          </div>
        </section>
        <section className="mhb-card">
          <h2 style={{ marginTop: 0 }}>健康概览</h2>
          <p>最近就诊：{patient.lastVisitAt}</p>
          <p>历史就诊：{vm.data.encounters.length} 次</p>
        </section>
      </div>

      <section className="mhb-table-wrap">
        <table className="mhb-table">
          <thead>
            <tr>
              <th>就诊</th>
              <th>医生</th>
              <th>诊断</th>
              <th>状态</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {vm.data.encounters.map((encounter) => (
              <tr key={encounter.id}>
                <td>{encounter.updatedAt}</td>
                <td>{encounter.doctorName}</td>
                <td>{encounter.diagnosis}</td>
                <td>
                  <HisStatusChip tone="info">
                    {encounterStatusLabels[encounter.status]}
                  </HisStatusChip>
                </td>
                <td>
                  <Link
                    className="mhb-button secondary"
                    to={`/encounters/${encounter.id}`}
                  >
                    就诊详情
                  </Link>
                </td>
              </tr>
            ))}
            {vm.data.invoices.map((invoice) => (
              <tr key={invoice.id}>
                <td>{invoice.createdAt}</td>
                <td>收费</td>
                <td>{invoice.items.map((item) => item.name).join("、")}</td>
                <td>
                  <HisStatusChip
                    tone={invoice.status === "paid" ? "success" : "warning"}
                  >
                    {invoiceStatusLabels[invoice.status]}
                  </HisStatusChip>
                </td>
                <td>
                  <Link className="mhb-button secondary" to="/billing">
                    查看账单
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
