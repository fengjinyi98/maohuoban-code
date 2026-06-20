import type { Invoice } from "../../../shared/api/types";
import { apiRequest, toJsonBody } from "../../../shared/api/http";
import { sessionHeaders } from "../../../shared/api/sessionHeaders";
import type { PaymentMethod } from "../domain/models";

export function listInvoices() {
  return apiRequest<Invoice[]>("/api/mock/his/invoices");
}

export function payInvoice(invoiceId: string, paymentMethod: PaymentMethod) {
  return apiRequest<Invoice>(`/api/mock/his/invoices/${invoiceId}/pay`, {
    ...toJsonBody({ paymentMethod }),
    headers: sessionHeaders(),
  });
}

export function refundInvoice(invoiceId: string, reason: string) {
  return apiRequest<Invoice>(`/api/mock/his/invoices/${invoiceId}/refund`, {
    ...toJsonBody({ reason }),
    headers: sessionHeaders(),
  });
}
