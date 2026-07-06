import { Button, Card } from "@heroui/react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import type { Role } from "../../../shared/api/types";
import { readSession } from "../../../shared/auth/sessionStorage";
import { roleLabels } from "../../../shared/permissions/permissions";
import { useAuthViewModel } from "../view-models/useAuthViewModel";

// ContextSelectPage 医院上下文选择页
// 核心职责：
// - 选择当前医院租户和院区
// - 使用后端返回的真实员工角色
export function ContextSelectPage() {
  const navigate = useNavigate();
  const { contextMutation, contextOptionsQuery } = useAuthViewModel();
  const session = readSession();
  const allTenants = contextOptionsQuery.data?.tenants ?? [];
  const availableSites = useMemo(() => {
    const allSites = contextOptionsQuery.data?.sites ?? [];
    return allSites.filter((site) => session?.member.siteIds.includes(site.id));
  }, [contextOptionsQuery.data?.sites, session?.member.siteIds]);
  const [tenantId, setTenantId] = useState(session?.member.tenantId ?? "");
  const [siteId, setSiteId] = useState("");
  const [role] = useState<Role>(session?.role ?? "doctor");

  const selectedTenantId =
    tenantId || session?.member.tenantId || allTenants[0]?.id || "";
  const selectedSiteId = siteId || availableSites[0]?.id || "";

  async function submit() {
    await contextMutation.mutateAsync({
      tenantId: selectedTenantId,
      siteId: selectedSiteId,
      role,
    });
    navigate("/dashboard");
  }

  return (
    <main
      style={{
        display: "grid",
        minHeight: "100vh",
        placeItems: "center",
        padding: 24,
      }}
    >
      <Card className="w-full max-w-[560px]">
        <Card.Header>
          <Card.Title>选择医院工作上下文</Card.Title>
          <Card.Description>
            当前账号只能进入已绑定的 HIS 医院租户和合作医院院区。
          </Card.Description>
        </Card.Header>
        <Card.Content className="mhb-grid">
          <label className="mhb-field">
            <span>医院租户</span>
            <select
              className="mhb-input"
              value={selectedTenantId}
              onChange={(event) => setTenantId(event.target.value)}
            >
              {allTenants.map((tenant) => (
                <option key={tenant.id} value={tenant.id}>
                  {tenant.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mhb-field">
            <span>院区</span>
            <select
              className="mhb-input"
              value={selectedSiteId}
              onChange={(event) => setSiteId(event.target.value)}
            >
              {availableSites.map((site) => (
                <option key={site.id} value={site.id}>
                  {site.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mhb-field">
            <span>角色</span>
            <input className="mhb-input" value={roleLabels[role]} disabled />
          </label>
        </Card.Content>
        <Card.Footer>
          <Button
            onPress={() => void submit()}
            isPending={contextMutation.isPending}
          >
            进入今日工作台
          </Button>
        </Card.Footer>
      </Card>
    </main>
  );
}
