import {
  Bell,
  CircleHelp,
  Hospital,
  LogOut,
  Search,
  ShieldCheck,
} from "lucide-react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { clearSession, readSession } from "../../shared/auth/sessionStorage";
import { navGroups } from "../../shared/design-system/navigation";
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
  const visibleGroups = navGroups
    .map((group) => ({
      ...group,
      items: group.items.filter((item) => hasPermission(role, item.permission)),
    }))
    .filter((group) => group.items.length > 0);
  const tenantName = session?.tenant?.name ?? "瑞派宠物医院";
  const siteName = session?.site?.name ?? "总院";
  const tenantTier =
    session?.tenant?.tier === "dedicated_tenant" ? "独立租户" : "标准租户";
  const userInitial = session?.member.name.slice(0, 1) ?? "医";

  function logout() {
    clearSession();
    navigate("/login");
  }

  return (
    <div className="mhb-shell">
      <aside className="mhb-sidebar">
        <div className="mhb-brand">
          <div className="mhb-brand-mark">
            <Hospital size={20} />
          </div>
          <strong>毛伙伴 HIS</strong>
        </div>

        <nav className="mhb-nav">
          {visibleGroups.map((group) => (
            <div className="mhb-nav-group" key={group.title}>
              <div className="mhb-nav-title">{group.title}</div>
              {group.items.map((item) => {
                const Icon = item.icon;
                return (
                  <NavLink
                    key={`${group.title}-${item.path}-${item.label}`}
                    to={item.path}
                    className={({ isActive }) =>
                      `mhb-nav-item${isActive ? " active" : ""}`
                    }
                  >
                    <Icon size={17} />
                    <span>{item.label}</span>
                  </NavLink>
                );
              })}
            </div>
          ))}
        </nav>

        <div className="mhb-sidebar-footer">
          <div className="mhb-user-card">
            <div className="mhb-user-avatar">{userInitial}</div>
            <div className="mhb-user-meta">
              <strong>{session?.member.name}</strong>
              <span>
                {roleLabels[role]}
                <ShieldCheck size={12} />
              </span>
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

      <section className="mhb-main-wrapper">
        <header className="mhb-topbar">
          <div className="mhb-tenant">
            <strong>
              {tenantName} - {siteName}
            </strong>
            <span>{tenantTier}</span>
          </div>
          <div className="mhb-top-actions">
            <label className="mhb-global-search">
              <Search size={16} />
              <input placeholder="搜索手机号、宠物名或病历号..." />
            </label>
            <button className="mhb-icon-button" aria-label="通知" type="button">
              <Bell size={18} />
              <span />
            </button>
            <button className="mhb-icon-button" aria-label="帮助" type="button">
              <CircleHelp size={18} />
            </button>
          </div>
        </header>
        <main className="mhb-main">
          <Outlet />
        </main>
      </section>
    </div>
  );
}
