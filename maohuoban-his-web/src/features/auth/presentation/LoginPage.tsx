import { Button, Card } from "@heroui/react";
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuthViewModel } from "../view-models/useAuthViewModel";

// LoginPage 员工登录页
// 核心职责：
// - 支持真实医院员工手机号密码登录
// - 登录后读取 HIS 员工与医院上下文
export function LoginPage() {
  const navigate = useNavigate();
  const [account, setAccount] = useState("13900000001");
  const [password, setPassword] = useState("");
  const { loginMutation } = useAuthViewModel();

  async function submit() {
    await loginMutation.mutateAsync({ account, password });
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
            连接毛伙伴开发库，读取合作医院预约、真实医院租户和员工账号，承载接诊与病历回流闭环。
          </p>
        </div>
      </section>
      <section style={{ padding: 32, display: "grid", alignContent: "center" }}>
        <Card>
          <Card.Header>
            <Card.Title>员工登录</Card.Title>
            <Card.Description>
              使用已绑定 HIS 员工身份的手机号和密码进入医院工作台。
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
        </Card>
      </section>
    </main>
  );
}
