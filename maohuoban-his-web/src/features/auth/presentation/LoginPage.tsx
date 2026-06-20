import { Button, Card } from "@heroui/react";
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { roleLabels } from "../../../shared/permissions/permissions";
import type { Role } from "../../../shared/api/types";
import { useAuthViewModel } from "../view-models/useAuthViewModel";

const accounts: Array<{ account: string; role: Role; name: string }> = [
  { account: "owner@mhb.test", role: "owner", name: "林院长" },
  { account: "doctor@mhb.test", role: "doctor", name: "周医生" },
  { account: "frontdesk@mhb.test", role: "frontdesk", name: "陈前台" },
  { account: "pharmacy@mhb.test", role: "pharmacy", name: "王药房" },
  { account: "finance@mhb.test", role: "finance", name: "赵财务" },
];

// LoginPage mock 登录页
// 核心职责：
// - 支持医院员工账号登录
// - 开发阶段提供角色快速入口
export function LoginPage() {
  const navigate = useNavigate();
  const [account, setAccount] = useState(accounts[0].account);
  const [password, setPassword] = useState("maohuoban");
  const { loginMutation } = useAuthViewModel();

  async function submit(nextAccount = account) {
    await loginMutation.mutateAsync({ account: nextAccount, password });
    navigate("/select-context");
  }

  return (
    <main
      style={{
        display: "grid",
        minHeight: "100vh",
        gridTemplateColumns: "minmax(0, 1fr) minmax(360px, 460px)",
      }}
    >
      <section
        style={{
          padding: 48,
          display: "grid",
          alignContent: "center",
          background: "var(--mhb-panel-soft)",
        }}
      >
        <div style={{ maxWidth: 680 }}>
          <p className="mhb-chip success">医院内部可信医疗业务系统</p>
          <h1 style={{ margin: "18px 0 12px", fontSize: 40, lineHeight: 1.1 }}>
            毛伙伴医院 HIS
          </h1>
          <p
            style={{ color: "var(--mhb-muted)", fontSize: 17, lineHeight: 1.7 }}
          >
            通过 mock
            数据跑通预约到院、接诊病历、处方收费、药房发药、健康档案发布和授权审计闭环。
          </p>
        </div>
      </section>
      <section style={{ padding: 32, display: "grid", alignContent: "center" }}>
        <Card>
          <Card.Header>
            <Card.Title>员工登录</Card.Title>
            <Card.Description>
              选择一个 mock 员工账号进入医院工作台。
            </Card.Description>
          </Card.Header>
          <Card.Content className="mhb-grid">
            <label className="mhb-field">
              <span>手机号 / 邮箱</span>
              <input
                className="mhb-input"
                value={account}
                onChange={(event) => setAccount(event.target.value)}
              />
            </label>
            <label className="mhb-field">
              <span>密码</span>
              <input
                className="mhb-input"
                type="password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
              />
            </label>
            {loginMutation.error ? (
              <p style={{ color: "var(--mhb-danger)" }}>
                {loginMutation.error.message}
              </p>
            ) : null}
            <Button
              onPress={() => void submit()}
              isPending={loginMutation.isPending}
            >
              登录
            </Button>
          </Card.Content>
          <Card.Footer className="mhb-grid">
            <div style={{ color: "var(--mhb-muted)", fontSize: 13 }}>
              快速角色入口
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
              {accounts.map((item) => (
                <Button
                  key={item.account}
                  variant="secondary"
                  size="sm"
                  onPress={() => void submit(item.account)}
                >
                  {item.name} · {roleLabels[item.role]}
                </Button>
              ))}
            </div>
          </Card.Footer>
        </Card>
      </section>
    </main>
  );
}
