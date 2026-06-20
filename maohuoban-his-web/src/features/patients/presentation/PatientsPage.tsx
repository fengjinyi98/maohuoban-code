import { Link } from "react-router-dom";
import { Plus, Search } from "lucide-react";
import { useState } from "react";
import { HisPageShell } from "../../../shared/components/HisPageShell";
import { HisStatusChip } from "../../../shared/components/HisStatusChip";
import { readSession } from "../../../shared/auth/sessionStorage";
import { hasPermission } from "../../../shared/permissions/permissions";
import { usePatientListViewModel } from "../view-models/usePatientListViewModel";

// PatientsPage 患者列表页
// 核心职责：
// - 支持宠物名、主人手机号、病历号和品种检索
// - 展示风险标签并提供详情入口
export function PatientsPage() {
  const [keyword, setKeyword] = useState("");
  const vm = usePatientListViewModel(keyword);
  const session = readSession();
  const canCreate = session
    ? hasPermission(session.role, "patients.create")
    : false;

  return (
    <HisPageShell
      title="宠物患者"
      description="按宠物、主人、病历号和品种检索院内患者。"
      actions={
        canCreate ? (
          <Link className="mhb-button primary" to="/patients/new">
            <Plus size={16} /> 新建患者
          </Link>
        ) : null
      }
    >
      <div
        className="mhb-card"
        style={{ display: "flex", gap: 10, alignItems: "center" }}
      >
        <Search size={18} />
        <input
          className="mhb-input"
          style={{ flex: 1 }}
          placeholder="搜索宠物名、主人手机号、病历号、品种"
          value={keyword}
          onChange={(event) => setKeyword(event.target.value)}
        />
      </div>

      <section className="mhb-table-wrap">
        <table className="mhb-table">
          <thead>
            <tr>
              <th>宠物</th>
              <th>主人</th>
              <th>病历号</th>
              <th>基础信息</th>
              <th>风险</th>
              <th>最近就诊</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {vm.data?.map((patient) => (
              <tr key={patient.id}>
                <td>
                  <strong>{patient.name}</strong>
                  <br />
                  <span style={{ color: "var(--mhb-muted)" }}>
                    {patient.species} · {patient.breed}
                  </span>
                </td>
                <td>
                  {patient.ownerName}
                  <br />
                  <span style={{ color: "var(--mhb-muted)" }}>
                    {patient.ownerPhone}
                  </span>
                </td>
                <td>{patient.medicalRecordNo}</td>
                <td>
                  {patient.ageText} · {patient.sex} · {patient.weightKg}kg
                </td>
                <td style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
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
                  {!patient.allergies.length &&
                  !patient.chronicDiseases.length &&
                  !patient.currentMedications.length ? (
                    <HisStatusChip>无高风险</HisStatusChip>
                  ) : null}
                </td>
                <td>{patient.lastVisitAt}</td>
                <td>
                  <Link
                    className="mhb-button secondary"
                    to={`/patients/${patient.id}`}
                  >
                    详情
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
