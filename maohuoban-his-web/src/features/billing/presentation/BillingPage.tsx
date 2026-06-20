import { useState } from "react";
import { HisPageShell } from "../../../shared/components/HisPageShell";
import { HisStatusChip } from "../../../shared/components/HisStatusChip";
import {
  formatCurrency,
  invoiceStatusLabels,
  invoiceTotal,
} from "../../../shared/utils/statusLabels";
import { useBillingViewModel } from "../view-models/useBillingViewModel";

// BillingPage 收费页
// 核心职责：
// - 展示待收费账单和收据预览
// - 支持 mock 收款、退款原因和审计记录生成
export function BillingPage() {
  const vm = useBillingViewModel();
  const [refundReasons, setRefundReasons] = useState<Record<string, string>>(
    {},
  );

  return (
    <HisPageShell
      title="收费"
      description="前台和财务处理待收费、收款、收据预览和退款。"
    >
      <section className="mhb-table-wrap">
        <table className="mhb-table">
          <thead>
            <tr>
              <th>宠物</th>
              <th>主人</th>
              <th>项目</th>
              <th>金额</th>
              <th>状态</th>
              <th>收据预览</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {vm.data?.map((invoice) => (
              <tr key={invoice.id}>
                <td>{invoice.patientName}</td>
                <td>{invoice.ownerName}</td>
                <td>
                  {invoice.items
                    .map((item) => `${item.name} x${item.quantity}`)
                    .join("、")}
                </td>
                <td>
                  <strong>{formatCurrency(invoiceTotal(invoice.items))}</strong>
                </td>
                <td>
                  <HisStatusChip
                    tone={
                      invoice.status === "paid"
                        ? "success"
                        : invoice.status === "unpaid"
                          ? "warning"
                          : "danger"
                    }
                  >
                    {invoiceStatusLabels[invoice.status]}
                  </HisStatusChip>
                </td>
                <td>
                  <div style={{ color: "var(--mhb-muted)" }}>
                    毛伙伴 HIS 收据
                    <br />
                    {invoice.id} · {invoice.createdAt}
                  </div>
                </td>
                <td style={{ minWidth: 260 }}>
                  {invoice.status === "unpaid" ? (
                    <button
                      className="mhb-button primary"
                      disabled={!vm.canCharge}
                      onClick={() =>
                        vm.payMutation.mutate({
                          invoiceId: invoice.id,
                          paymentMethod: "wechat",
                        })
                      }
                    >
                      微信收款
                    </button>
                  ) : (
                    <div style={{ display: "grid", gap: 8 }}>
                      <input
                        className="mhb-input"
                        placeholder="退款原因"
                        value={refundReasons[invoice.id] ?? ""}
                        onChange={(event) =>
                          setRefundReasons({
                            ...refundReasons,
                            [invoice.id]: event.target.value,
                          })
                        }
                      />
                      <button
                        className="mhb-button danger"
                        disabled={!vm.canRefund}
                        onClick={() =>
                          vm.refundMutation.mutate({
                            invoiceId: invoice.id,
                            reason: refundReasons[invoice.id] ?? "",
                          })
                        }
                      >
                        申请退款
                      </button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </HisPageShell>
  );
}
