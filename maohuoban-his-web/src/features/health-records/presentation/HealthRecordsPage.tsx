import { HisPageShell } from "../../../shared/components/HisPageShell";
import { HisStatusChip } from "../../../shared/components/HisStatusChip";
import { publicationStatusLabels } from "../../../shared/utils/statusLabels";
import { useHealthRecordsViewModel } from "../view-models/useHealthRecordsViewModel";

// HealthRecordsPage 健康档案发布页
// 核心职责：
// - 审核发布到宠物主 App 的摘要
// - 明确隔离内部备注、成本、利润和方案模板
export function HealthRecordsPage() {
  const vm = useHealthRecordsViewModel();

  return (
    <HisPageShell
      title="健康档案"
      description="医生审核 App 发布版摘要，保护医院原始 HIS 记录和内部资产。"
    >
      <div className="mhb-grid mhb-grid-2">
        {vm.data?.map((publication) => (
          <section className="mhb-card mhb-grid" key={publication.id}>
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                gap: 12,
              }}
            >
              <h2 style={{ margin: 0 }}>{publication.patientName}</h2>
              <HisStatusChip
                tone={
                  publication.status === "published"
                    ? "success"
                    : publication.status === "pending"
                      ? "warning"
                      : "info"
                }
              >
                {publicationStatusLabels[publication.status]}
              </HisStatusChip>
            </div>
            <div
              className="mhb-card"
              style={{ background: "var(--mhb-panel-soft)" }}
            >
              <strong>宠物主 App 预览</strong>
              <p>
                <b>诊断摘要：</b>
                {publication.diagnosisSummary}
              </p>
              <p>
                <b>用药摘要：</b>
                {publication.medicationSummary}
              </p>
              <p>
                <b>报告摘要：</b>
                {publication.reportSummary}
              </p>
              <p>
                <b>复诊建议：</b>
                {publication.followUpAdvice}
              </p>
            </div>
            <div className="mhb-card">
              <strong>敏感隔离检查</strong>
              <p style={{ color: "var(--mhb-muted)" }}>
                内部备注、成本、利润、方案模板未进入发布预览。
              </p>
            </div>
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
              <button
                className="mhb-button primary"
                disabled={!vm.canPublish}
                onClick={() =>
                  vm.updateMutation.mutate({
                    publicationId: publication.id,
                    action: "publish",
                  })
                }
              >
                发布
              </button>
              <button
                className="mhb-button secondary"
                disabled={!vm.canPublish}
                onClick={() =>
                  vm.updateMutation.mutate({
                    publicationId: publication.id,
                    action: "delay",
                  })
                }
              >
                延迟发布
              </button>
              <button
                className="mhb-button danger"
                disabled={!vm.canPublish}
                onClick={() =>
                  vm.updateMutation.mutate({
                    publicationId: publication.id,
                    action: "block",
                  })
                }
              >
                不发布
              </button>
            </div>
          </section>
        ))}
      </div>
    </HisPageShell>
  );
}
