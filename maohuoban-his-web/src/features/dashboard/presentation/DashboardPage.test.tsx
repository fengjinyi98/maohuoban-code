import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it } from "vitest";
import type { DashboardToday } from "../../../shared/api/types";
import { DashboardPage } from "./DashboardPage";

function renderDashboard(data: DashboardToday) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  queryClient.setQueryData(["dashboard", "today"], data);

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <DashboardPage />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("DashboardPage", () => {
  it("renders real appointment rows in today's queue", () => {
    renderDashboard({
      summary: {
        appointments: 1,
        pendingEncounter: 0,
        pendingBilling: 0,
        pendingDispense: 0,
        pendingPublication: 0,
      },
      appointments: [
        {
          id: "appointment-1",
          patientId: "pet-1",
          patientName: "馒头",
          ownerName: "宠物主",
          startsAt: "21:27",
          reason: "异常后就医",
          status: "scheduled",
        },
      ],
      encounters: [],
      invoices: [],
      inventoryRisks: [],
      publications: [],
    });

    expect(screen.getByText("馒头")).toBeInTheDocument();
    expect(screen.getByText("异常后就医")).toBeInTheDocument();
    expect(screen.getByText("21:27")).toBeInTheDocument();
  });
});
