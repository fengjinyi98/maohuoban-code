import { http, HttpResponse } from "msw";
import type {
  AuthSession,
  Invoice,
  InvoiceItem,
  PetPatient,
  PrescriptionItem,
} from "../api/types";
import { mockState, addAudit, parseSessionHeader } from "./state";

function error(
  status: number,
  code: "UNAUTHORIZED" | "FORBIDDEN" | "NOT_FOUND" | "CONFLICT" | "INTERNAL",
  message: string,
) {
  return HttpResponse.json({ code, message }, { status });
}

function sessionFromMember(account: string): AuthSession | null {
  const member = mockState.members.find((item) => item.account === account);
  if (!member || !member.enabled) {
    return null;
  }
  return { member, role: member.role };
}

function buildDashboard() {
  return {
    summary: {
      appointments: 5,
      pendingEncounter: mockState.encounters.filter((item) =>
        ["triage", "in_progress"].includes(item.status),
      ).length,
      pendingBilling: mockState.invoices.filter(
        (item) => item.status === "unpaid",
      ).length,
      pendingDispense: mockState.encounters.filter(
        (item) => item.status === "pending_dispense",
      ).length,
      pendingPublication: mockState.publications.filter(
        (item) => item.status === "pending",
      ).length,
    },
    appointments: [
      {
        id: "ap-001",
        patientId: "p-001",
        patientName: "奶糖",
        ownerName: "李女士",
        startsAt: "09:00",
        reason: "肾病复查",
        status: "arrived",
      },
      {
        id: "ap-002",
        patientId: "p-002",
        patientName: "闪电",
        ownerName: "王先生",
        startsAt: "09:30",
        reason: "年度免疫",
        status: "arrived",
      },
      {
        id: "ap-003",
        patientId: "p-003",
        patientName: "团子",
        ownerName: "张女士",
        startsAt: "10:00",
        reason: "猫传腹复查",
        status: "arrived",
      },
      {
        id: "ap-004",
        patientId: "p-004",
        patientName: "可乐",
        ownerName: "沈先生",
        startsAt: "14:30",
        reason: "心脏病复诊",
        status: "scheduled",
      },
      {
        id: "ap-005",
        patientId: "p-005",
        patientName: "豆花",
        ownerName: "赵女士",
        startsAt: "16:00",
        reason: "驱虫",
        status: "scheduled",
      },
    ],
    encounters: mockState.encounters,
    invoices: mockState.invoices,
    inventoryRisks: mockState.inventory.filter(
      (item) => item.status !== "normal" || item.stock <= item.threshold,
    ),
    publications: mockState.publications,
  };
}

export const handlers = [
  http.post("/api/mock/auth/login", async ({ request }) => {
    const body = (await request.json()) as { account: string };
    const session = sessionFromMember(body.account);
    if (!session) {
      return error(403, "FORBIDDEN", "账号不存在或已停用");
    }

    return HttpResponse.json({
      session,
      tenants: mockState.tenants.filter(
        (tenant) =>
          tenant.id === session.member.tenantId ||
          session.member.account === "chain@mhb.test",
      ),
      sites: mockState.sites.filter((site) =>
        session.member.siteIds.includes(site.id),
      ),
      members: mockState.members,
    });
  }),

  http.post("/api/mock/auth/context", async ({ request }) => {
    const body = (await request.json()) as {
      session: AuthSession;
      tenantId: string;
      siteId: string;
      role?: AuthSession["role"];
    };
    const tenant = mockState.tenants.find((item) => item.id === body.tenantId);
    const site = mockState.sites.find((item) => item.id === body.siteId);
    if (!tenant || !site) {
      return error(404, "NOT_FOUND", "医院或院区不存在");
    }
    return HttpResponse.json({
      ...body.session,
      tenant,
      site,
      role: body.role ?? body.session.role,
    });
  }),

  http.get("/api/mock/auth/context-options", () =>
    HttpResponse.json({
      tenants: mockState.tenants,
      sites: mockState.sites,
    }),
  ),

  http.get("/api/mock/his/dashboard/today", () =>
    HttpResponse.json(buildDashboard()),
  ),

  http.get("/api/mock/his/patients", ({ request }) => {
    const url = new URL(request.url);
    const keyword = url.searchParams.get("keyword")?.trim();
    const data = keyword
      ? mockState.patients.filter((patient) =>
          [
            patient.name,
            patient.ownerName,
            patient.ownerPhone,
            patient.medicalRecordNo,
            patient.breed,
          ].some((value) => value.includes(keyword)),
        )
      : mockState.patients;
    return HttpResponse.json(data);
  }),

  http.post("/api/mock/his/patients", async ({ request }) => {
    const body = (await request.json()) as Omit<
      PetPatient,
      "id" | "medicalRecordNo" | "lastVisitAt"
    >;
    const patient: PetPatient = {
      ...body,
      id: `p-${Date.now()}`,
      medicalRecordNo: `MHB${Date.now()}`,
      lastVisitAt: "新建",
    };
    mockState.patients.unshift(patient);
    addAudit(
      parseSessionHeader(request),
      "edit",
      `${patient.name} 患者档案`,
      "新建患者",
      false,
    );
    return HttpResponse.json(patient);
  }),

  http.get("/api/mock/his/patients/:patientId", ({ params }) => {
    const patient = mockState.patients.find(
      (item) => item.id === params.patientId,
    );
    if (!patient) {
      return error(404, "NOT_FOUND", "患者不存在");
    }
    return HttpResponse.json({
      patient,
      encounters: mockState.encounters.filter(
        (item) => item.patientId === patient.id,
      ),
      invoices: mockState.invoices.filter((invoice) =>
        mockState.encounters.some(
          (encounter) =>
            encounter.id === invoice.encounterId &&
            encounter.patientId === patient.id,
        ),
      ),
    });
  }),

  http.get("/api/mock/his/encounters/:encounterId?", ({ params }) => {
    const encounterId = params.encounterId;
    if (!encounterId) {
      return HttpResponse.json(mockState.encounters);
    }
    const encounter = mockState.encounters.find(
      (item) => item.id === encounterId,
    );
    if (!encounter) {
      return error(404, "NOT_FOUND", "就诊不存在");
    }
    return HttpResponse.json(encounter);
  }),

  http.post(
    "/api/mock/his/encounters/:encounterId/start",
    ({ params, request }) => {
      const encounter = mockState.encounters.find(
        (item) => item.id === params.encounterId,
      );
      if (!encounter) {
        return error(404, "NOT_FOUND", "就诊不存在");
      }
      encounter.status = "in_progress";
      encounter.updatedAt = new Date().toLocaleString("zh-CN", {
        hour12: false,
      });
      addAudit(
        parseSessionHeader(request),
        "edit",
        `${encounter.patientName} 接诊`,
        "开始接诊",
        false,
      );
      return HttpResponse.json(encounter);
    },
  ),

  http.post(
    "/api/mock/his/encounters/:encounterId/save",
    async ({ params, request }) => {
      const encounter = mockState.encounters.find(
        (item) => item.id === params.encounterId,
      );
      if (!encounter) {
        return error(404, "NOT_FOUND", "就诊不存在");
      }
      const body = (await request.json()) as Partial<
        Pick<
          typeof encounter,
          | "chiefComplaint"
          | "diagnosis"
          | "vitals"
          | "orders"
          | "prescriptionItems"
          | "followUpAdvice"
        >
      >;
      Object.assign(encounter, body, {
        status: body.prescriptionItems?.length
          ? "pending_billing"
          : "pending_report",
        updatedAt: new Date().toLocaleString("zh-CN", { hour12: false }),
      });

      if (
        body.prescriptionItems?.length &&
        !mockState.invoices.some(
          (invoice) => invoice.encounterId === encounter.id,
        )
      ) {
        const drugItems: InvoiceItem[] = body.prescriptionItems.map(
          (item: PrescriptionItem) => ({
            id: `fee-${item.id}`,
            name: item.name,
            type: "drug",
            quantity: item.quantity,
            unitPrice: item.unitPrice,
          }),
        );
        mockState.invoices.unshift({
          id: `inv-${Date.now()}`,
          encounterId: encounter.id,
          patientName: encounter.patientName,
          ownerName: encounter.ownerName,
          status: "unpaid",
          items: [
            {
              id: `fee-service-${Date.now()}`,
              name: "门诊接诊",
              type: "service",
              quantity: 1,
              unitPrice: 60,
            },
            ...drugItems,
          ],
          createdAt: new Date().toLocaleString("zh-CN", { hour12: false }),
        });
      }

      addAudit(
        parseSessionHeader(request),
        "edit",
        `${encounter.patientName} 病历`,
        "保存病历和处方",
        true,
      );
      return HttpResponse.json(encounter);
    },
  ),

  http.get("/api/mock/his/invoices", () =>
    HttpResponse.json(mockState.invoices),
  ),

  http.post(
    "/api/mock/his/invoices/:invoiceId/pay",
    async ({ params, request }) => {
      const invoice = mockState.invoices.find(
        (item) => item.id === params.invoiceId,
      );
      if (!invoice) {
        return error(404, "NOT_FOUND", "收费单不存在");
      }
      const body = (await request.json()) as {
        paymentMethod: Invoice["paymentMethod"];
      };
      invoice.status = "paid";
      invoice.paymentMethod = body.paymentMethod;
      const encounter = mockState.encounters.find(
        (item) => item.id === invoice.encounterId,
      );
      if (encounter?.prescriptionItems.length) {
        encounter.status = "pending_dispense";
      }
      addAudit(
        parseSessionHeader(request),
        "edit",
        `${invoice.patientName} 收费`,
        "确认收款",
        true,
      );
      return HttpResponse.json(invoice);
    },
  ),

  http.post(
    "/api/mock/his/invoices/:invoiceId/refund",
    async ({ params, request }) => {
      const invoice = mockState.invoices.find(
        (item) => item.id === params.invoiceId,
      );
      if (!invoice) {
        return error(404, "NOT_FOUND", "收费单不存在");
      }
      const body = (await request.json()) as { reason: string };
      if (!body.reason?.trim()) {
        return error(409, "CONFLICT", "退款必须填写原因");
      }
      invoice.status = "refund_pending";
      invoice.refundReason = body.reason;
      addAudit(
        parseSessionHeader(request),
        "refund",
        `${invoice.patientName} 退款`,
        body.reason,
        true,
      );
      return HttpResponse.json(invoice);
    },
  ),

  http.get("/api/mock/his/pharmacy", () =>
    HttpResponse.json({
      dispensing: mockState.encounters.filter(
        (item) => item.status === "pending_dispense",
      ),
      inventory: mockState.inventory,
    }),
  ),

  http.post(
    "/api/mock/his/pharmacy/:encounterId/dispense",
    async ({ params, request }) => {
      const encounter = mockState.encounters.find(
        (item) => item.id === params.encounterId,
      );
      if (!encounter) {
        return error(404, "NOT_FOUND", "发药任务不存在");
      }
      for (const rx of encounter.prescriptionItems) {
        const item = mockState.inventory.find(
          (inventoryItem) => inventoryItem.id === rx.inventoryItemId,
        );
        if (item) {
          item.stock = Math.max(0, item.stock - rx.quantity);
          item.batches[0].stock = Math.max(
            0,
            item.batches[0].stock - rx.quantity,
          );
          if (item.stock <= item.threshold) {
            item.status = "low_stock";
          }
        }
      }
      encounter.status = "completed";
      addAudit(
        parseSessionHeader(request),
        "edit",
        `${encounter.patientName} 发药`,
        "确认批号并完成发药",
        true,
      );
      return HttpResponse.json({ encounter, inventory: mockState.inventory });
    },
  ),

  http.get("/api/mock/his/health-record-publications", () =>
    HttpResponse.json(mockState.publications),
  ),

  http.post(
    "/api/mock/his/health-record-publications/:publicationId/:action",
    ({ params, request }) => {
      const publication = mockState.publications.find(
        (item) => item.id === params.publicationId,
      );
      if (!publication) {
        return error(404, "NOT_FOUND", "健康档案不存在");
      }
      if (params.action === "publish") {
        publication.status = "published";
        publication.publishedAt = new Date().toLocaleString("zh-CN", {
          hour12: false,
        });
        publication.publishedBy =
          parseSessionHeader(request)?.member.name ?? "mock 系统";
        publication.version += 1;
        addAudit(
          parseSessionHeader(request),
          "publish",
          `${publication.patientName} 健康档案`,
          "发布到宠物主 App",
          true,
        );
      } else if (params.action === "delay") {
        publication.status = "delayed";
        addAudit(
          parseSessionHeader(request),
          "publish",
          `${publication.patientName} 健康档案`,
          "延迟发布等待补充报告",
          true,
        );
      } else if (params.action === "block") {
        publication.status = "blocked";
        addAudit(
          parseSessionHeader(request),
          "publish",
          `${publication.patientName} 健康档案`,
          "不发布内部记录",
          true,
        );
      }
      return HttpResponse.json(publication);
    },
  ),

  http.get("/api/mock/his/audit-logs", ({ request }) => {
    const url = new URL(request.url);
    const keyword = url.searchParams.get("keyword")?.trim();
    const action = url.searchParams.get("action");
    const logs = mockState.auditLogs.filter((log) => {
      const keywordMatched = keyword
        ? [log.actorName, log.target, log.reason].some((value) =>
            value.includes(keyword),
          )
        : true;
      const actionMatched = action ? log.action === action : true;
      return keywordMatched && actionMatched;
    });
    return HttpResponse.json({ logs, consents: mockState.consents });
  }),

  http.get("/api/mock/his/settings", () =>
    HttpResponse.json({
      members: mockState.members,
      sites: mockState.sites,
      inventory: mockState.inventory,
      roles: [
        "owner",
        "doctor",
        "assistant",
        "frontdesk",
        "pharmacy",
        "finance",
      ],
    }),
  ),
];
