import { HisPageShell } from "../../../shared/components/HisPageShell";
import { HisStatusChip } from "../../../shared/components/HisStatusChip";
import { usePharmacyViewModel } from "../view-models/usePharmacyViewModel";

// PharmacyPage 药房库存页
// 核心职责：
// - 展示待发药处方、批号和用法
// - 展示库存、低库存和近效期预警
export function PharmacyPage() {
  const vm = usePharmacyViewModel();

  return (
    <HisPageShell
      title="药房库存"
      description="药房确认批号、完成发药并扣减 mock 库存。"
    >
      <div className="mhb-grid mhb-grid-2">
        <section className="mhb-card">
          <h2 style={{ marginTop: 0 }}>待发药</h2>
          <div className="mhb-grid">
            {vm.data?.dispensing.map((encounter) => (
              <div className="mhb-card" key={encounter.id}>
                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    gap: 12,
                  }}
                >
                  <strong>{encounter.patientName}</strong>
                  <HisStatusChip tone="warning">待发药</HisStatusChip>
                </div>
                <p>
                  {encounter.prescriptionItems
                    .map(
                      (item) => `${item.name} ${item.dosage} ${item.frequency}`,
                    )
                    .join("、")}
                </p>
                <p style={{ color: "var(--mhb-muted)" }}>
                  默认批号按近效期优先选择，发药后扣减库存。
                </p>
                <button
                  className="mhb-button primary"
                  disabled={!vm.canDispense}
                  onClick={() => vm.dispenseMutation.mutate(encounter.id)}
                >
                  确认发药
                </button>
              </div>
            ))}
            {vm.data?.dispensing.length === 0 ? (
              <p style={{ color: "var(--mhb-muted)" }}>暂无待发药任务。</p>
            ) : null}
          </div>
        </section>

        <section className="mhb-card">
          <h2 style={{ marginTop: 0 }}>库存预警</h2>
          <div className="mhb-grid">
            {vm.data?.inventory.map((item) => (
              <div className="mhb-card" key={item.id}>
                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    gap: 12,
                  }}
                >
                  <strong>{item.name}</strong>
                  <HisStatusChip
                    tone={
                      item.status === "normal"
                        ? "success"
                        : item.status === "low_stock"
                          ? "danger"
                          : "warning"
                    }
                  >
                    {item.status === "normal"
                      ? "正常"
                      : item.status === "low_stock"
                        ? "低库存"
                        : item.status === "near_expiry"
                          ? "近效期"
                          : "停用"}
                  </HisStatusChip>
                </div>
                <p>
                  {item.specification} · 库存 {item.stock}
                  {item.unit} · 阈值 {item.threshold}
                  {item.unit}
                </p>
                <p style={{ color: "var(--mhb-muted)" }}>
                  批号 {item.batches[0]?.batchNo} · 有效期{" "}
                  {item.batches[0]?.expiresAt}
                </p>
              </div>
            ))}
          </div>
        </section>
      </div>
    </HisPageShell>
  );
}
