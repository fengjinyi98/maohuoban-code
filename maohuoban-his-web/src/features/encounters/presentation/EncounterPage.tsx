import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import type { VisitEncounter } from "../../../shared/api/types";
import { HisPageShell } from "../../../shared/components/HisPageShell";
import { HisStatusChip } from "../../../shared/components/HisStatusChip";
import { encounterStatusLabels } from "../../../shared/utils/statusLabels";
import { useEncounterViewModel } from "../view-models/useEncounterViewModel";

// EncounterPage 接诊病历页
// 核心职责：
// - 展示接诊队列和病历编辑表单
// - 跑通保存病历、开处方和生成待收费任务
export function EncounterPage() {
  const { encounterId } = useParams();
  const vm = useEncounterViewModel(encounterId);
  const encounter = vm.detailQuery.data;

  if (!encounterId) {
    return (
      <HisPageShell
        title="接诊病历"
        description="医生和助理处理待接诊、接诊中和待补报告队列。"
      >
        <section className="mhb-table-wrap">
          <table className="mhb-table">
            <thead>
              <tr>
                <th>宠物</th>
                <th>主人</th>
                <th>主诉</th>
                <th>诊断</th>
                <th>状态</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {vm.listQuery.data?.map((item) => (
                <tr key={item.id}>
                  <td>{item.patientName}</td>
                  <td>{item.ownerName}</td>
                  <td>{item.chiefComplaint}</td>
                  <td>{item.diagnosis}</td>
                  <td>
                    <HisStatusChip tone="info">
                      {encounterStatusLabels[item.status]}
                    </HisStatusChip>
                  </td>
                  <td>
                    <Link
                      className="mhb-button secondary"
                      to={`/encounters/${item.id}`}
                    >
                      打开
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

  if (!encounter) {
    return (
      <HisPageShell title="接诊病历">
        <div className="mhb-card">加载就诊详情...</div>
      </HisPageShell>
    );
  }

  const currentEncounter = encounter;

  return <EncounterEditor encounter={currentEncounter} vm={vm} />;
}

interface EncounterEditorProps {
  encounter: VisitEncounter;
  vm: ReturnType<typeof useEncounterViewModel>;
}

// EncounterEditor 病历编辑表单
// 核心职责：
// - 在就诊数据就绪后初始化本地草稿
// - 提供离开保护和保存命令
function EncounterEditor({ encounter, vm }: EncounterEditorProps) {
  const [chiefComplaint, setChiefComplaint] = useState(
    encounter.chiefComplaint,
  );
  const [diagnosis, setDiagnosis] = useState(encounter.diagnosis);
  const [followUpAdvice, setFollowUpAdvice] = useState(
    encounter.followUpAdvice,
  );
  const [hasDirtyDraft, setHasDirtyDraft] = useState(false);
  const currentEncounter = encounter;

  useEffect(() => {
    function beforeUnload(event: BeforeUnloadEvent) {
      if (hasDirtyDraft) {
        event.preventDefault();
      }
    }
    window.addEventListener("beforeunload", beforeUnload);
    return () => window.removeEventListener("beforeunload", beforeUnload);
  }, [hasDirtyDraft]);

  async function save() {
    await vm.saveMutation.mutateAsync({
      id: currentEncounter.id,
      payload: {
        chiefComplaint,
        diagnosis,
        followUpAdvice,
        orders: ["血常规", "生化检查", "皮下注射"],
        prescriptionItems: [
          {
            id: "rx-new-001",
            inventoryItemId: "i-001",
            name: "阿莫西林克拉维酸钾片",
            dosage: `${Math.max(0.25, Math.round(currentEncounter.vitals.weightKg / 8) * 0.5)}片`,
            frequency: "每日两次",
            route: "口服",
            days: 5,
            quantity: 1,
            unitPrice: 58,
          },
        ],
      },
    });
    setHasDirtyDraft(false);
  }

  return (
    <HisPageShell
      title={`${currentEncounter.patientName} · 接诊病历`}
      description={`${currentEncounter.ownerName} · ${currentEncounter.doctorName}`}
    >
      <section
        className="mhb-card"
        style={{
          display: "flex",
          gap: 10,
          flexWrap: "wrap",
          alignItems: "center",
        }}
      >
        <HisStatusChip tone="info">
          {encounterStatusLabels[currentEncounter.status]}
        </HisStatusChip>
        <HisStatusChip tone="warning">
          体重 {currentEncounter.vitals.weightKg}kg
        </HisStatusChip>
        <HisStatusChip tone="danger">处方需核对过敏史</HisStatusChip>
        {vm.canEdit && currentEncounter.status === "triage" ? (
          <button
            className="mhb-button primary"
            onClick={() => vm.startMutation.mutate(currentEncounter.id)}
          >
            开始接诊
          </button>
        ) : null}
      </section>

      <section className="mhb-card mhb-grid">
        <div className="mhb-grid mhb-grid-3">
          <label className="mhb-field">
            <span>主诉</span>
            <textarea
              className="mhb-input"
              rows={4}
              value={chiefComplaint}
              disabled={!vm.canEdit}
              onChange={(event) => {
                setChiefComplaint(event.target.value);
                setHasDirtyDraft(true);
              }}
            />
          </label>
          <label className="mhb-field">
            <span>诊断</span>
            <textarea
              className="mhb-input"
              rows={4}
              value={diagnosis}
              disabled={!vm.canEdit}
              onChange={(event) => {
                setDiagnosis(event.target.value);
                setHasDirtyDraft(true);
              }}
            />
          </label>
          <label className="mhb-field">
            <span>复诊建议</span>
            <textarea
              className="mhb-input"
              rows={4}
              value={followUpAdvice}
              disabled={!vm.canEdit}
              onChange={(event) => {
                setFollowUpAdvice(event.target.value);
                setHasDirtyDraft(true);
              }}
            />
          </label>
        </div>
        <div className="mhb-grid mhb-grid-3">
          <div className="mhb-card">
            <strong>体征</strong>
            <p>
              体温 {currentEncounter.vitals.temperatureC}℃ · 心率{" "}
              {currentEncounter.vitals.heartRate} · 呼吸{" "}
              {currentEncounter.vitals.respiration}
            </p>
          </div>
          <div className="mhb-card">
            <strong>医嘱</strong>
            <p>
              {currentEncounter.orders.join("、") ||
                "保存后生成检查、治疗和护理医嘱。"}
            </p>
          </div>
          <div className="mhb-card">
            <strong>剂量提示</strong>
            <p>
              按 {currentEncounter.vitals.weightKg}kg
              体重计算，阿莫西林克拉维酸钾建议从低剂量复核。
            </p>
          </div>
        </div>
        <div className="mhb-card">
          <strong>处方草稿</strong>
          <p style={{ color: "var(--mhb-muted)" }}>
            阿莫西林克拉维酸钾片 · 每日两次 · 口服 5 天。保存后生成待收费项。
          </p>
        </div>
        <button
          className="mhb-button primary"
          type="button"
          disabled={!vm.canEdit || vm.saveMutation.isPending}
          onClick={() => void save()}
        >
          保存病历并生成收费
        </button>
        {!vm.canEdit ? (
          <p style={{ color: "var(--mhb-danger)" }}>
            当前角色只能查看病历，不能编辑医生病历。
          </p>
        ) : null}
      </section>
    </HisPageShell>
  );
}
