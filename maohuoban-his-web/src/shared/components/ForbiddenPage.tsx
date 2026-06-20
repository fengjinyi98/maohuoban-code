import { Link } from "react-router-dom";

// ForbiddenPage 无权限页面
// 核心职责：
// - 解释当前角色无权访问
// - 提供返回工作台入口
export function ForbiddenPage() {
  return (
    <main
      style={{
        display: "grid",
        minHeight: "100vh",
        placeItems: "center",
        padding: 24,
      }}
    >
      <div className="mhb-card" style={{ maxWidth: 440 }}>
        <h1 style={{ marginTop: 0 }}>403 无权限访问</h1>
        <p style={{ color: "var(--mhb-muted)" }}>
          当前角色没有访问该模块或执行该操作的权限。请由院长或管理员调整角色权限。
        </p>
        <Link className="mhb-button primary" to="/dashboard">
          返回今日工作台
        </Link>
      </div>
    </main>
  );
}
