import { LogOut } from "lucide-react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { clearSession, readSession } from "../../shared/auth/sessionStorage";
import { navItems } from "../../shared/design-system/navigation";
import {
  hasPermission,
  roleLabels,
} from "../../shared/permissions/permissions";

// AppLayout 医院端后台布局
// 核心职责：
// - 展示系统导航和当前医院上下文
// - 承载所有登录后的业务页面
export function AppLayout() {
  const navigate = useNavigate();
  const session = readSession();
  const role = session?.role ?? "doctor";
  const visibleItems = navItems.filter((item) =>
    hasPermission(role, item.permission),
  );

  function logout() {
    clearSession();
    navigate("/login");
  }

  return (
    <div className="mhb-shell">
      <aside className="mhb-sidebar">
        <div style={{ display: "grid", gap: 4, marginBottom: 24 }}>
          <strong style={{ fontSize: 18 }}>毛伙伴 HIS</strong>
          <span style={{ color: "var(--mhb-muted)", fontSize: 13 }}>
            {session?.tenant?.name} · {session?.site?.name}
          </span>
        </div>
        <nav style={{ display: "grid", gap: 6 }}>
          {visibleItems.map((item) => {
            const Icon = item.icon;
            return (
              <NavLink
                key={item.path}
                to={item.path}
                style={({ isActive }) => ({
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                  borderRadius: 8,
                  padding: "10px 12px",
                  background: isActive ? "oklch(0.92 0.04 154)" : "transparent",
                  color: isActive
                    ? "var(--mhb-primary-strong)"
                    : "var(--mhb-text)",
                  fontWeight: isActive ? 750 : 600,
                })}
              >
                <Icon size={18} />
                {item.label}
              </NavLink>
            );
          })}
        </nav>
        <div style={{ marginTop: "auto", display: "grid", gap: 10 }}>
          <div className="mhb-card" style={{ padding: 12 }}>
            <strong>{session?.member.name}</strong>
            <div style={{ color: "var(--mhb-muted)", fontSize: 13 }}>
              {roleLabels[role]}
            </div>
          </div>
          <button
            className="mhb-button secondary"
            type="button"
            onClick={logout}
          >
            <LogOut size={16} />
            退出登录
          </button>
        </div>
      </aside>
      <main className="mhb-main">
        <Outlet />
      </main>
    </div>
  );
}
