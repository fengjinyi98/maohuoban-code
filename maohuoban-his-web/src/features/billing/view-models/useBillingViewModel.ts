import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { readSession } from "../../../shared/auth/sessionStorage";
import { hasPermission } from "../../../shared/permissions/permissions";
import {
  listInvoices,
  payInvoice,
  refundInvoice,
} from "../data/billingRepository";
import type { PaymentMethod } from "../domain/models";

// useBillingViewModel 收费状态
// 核心职责：
// - 加载待收费和已收费列表
// - 提供支付和退款命令入口
export function useBillingViewModel() {
  const queryClient = useQueryClient();
  const session = readSession();
  const query = useQuery({ queryKey: ["invoices"], queryFn: listInvoices });
  const canCharge = session
    ? hasPermission(session.role, "billing.charge")
    : false;
  const canRefund = session
    ? hasPermission(session.role, "billing.refund")
    : false;

  const payMutation = useMutation({
    mutationFn: ({
      invoiceId,
      paymentMethod,
    }: {
      invoiceId: string;
      paymentMethod: PaymentMethod;
    }) => payInvoice(invoiceId, paymentMethod),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["invoices"] });
      queryClient.invalidateQueries({ queryKey: ["dashboard"] });
      queryClient.invalidateQueries({ queryKey: ["pharmacy"] });
    },
  });

  const refundMutation = useMutation({
    mutationFn: ({
      invoiceId,
      reason,
    }: {
      invoiceId: string;
      reason: string;
    }) => refundInvoice(invoiceId, reason),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["invoices"] }),
  });

  return { ...query, canCharge, canRefund, payMutation, refundMutation };
}
