import type { BackendEnvelope, Invoice } from "../../../shared/api/types";
import { apiRequest, toJsonBody } from "../../../shared/api/http";
import { sessionHeaders } from "../../../shared/api/sessionHeaders";
import type { PaymentMethod } from "../domain/models";

export function listInvoices() {
  return apiRequest<BackendEnvelope<Invoice[]>>("/api/v1/his/invoices").then(
    (response) => response.data,
  );
}

export function payInvoice(invoiceId: string, paymentMethod: PaymentMethod) {
  return apiRequest<BackendEnvelope<Invoice>>(
    `/api/v1/his/invoices/${invoiceId}/pay`,
    {
    ...toJsonBody({ paymentMethod }),
    headers: sessionHeaders(),
    },
  ).then((response) => response.data);
}

export function refundInvoice(invoiceId: string, reason: string) {
  return apiRequest<BackendEnvelope<Invoice>>(
    `/api/v1/his/invoices/${invoiceId}/refund`,
    {
    ...toJsonBody({ reason }),
    headers: sessionHeaders(),
    },
  ).then((response) => response.data);
}
