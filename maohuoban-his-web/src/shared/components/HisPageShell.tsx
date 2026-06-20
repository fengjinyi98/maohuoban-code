import type { ReactNode } from "react";

interface HisPageShellProps {
  title: string;
  description?: string;
  actions?: ReactNode;
  children: ReactNode;
}

// HisPageShell 后台页面框架
// 核心职责：
// - 统一页面标题、说明和操作区
// - 保持业务内容区布局一致
export function HisPageShell({
  title,
  description,
  actions,
  children,
}: HisPageShellProps) {
  return (
    <section className="mhb-grid">
      <header
        style={{
          display: "flex",
          alignItems: "flex-start",
          justifyContent: "space-between",
          gap: 16,
        }}
      >
        <div>
          <h1 style={{ margin: 0, fontSize: 26, lineHeight: 1.2 }}>{title}</h1>
          {description ? (
            <p style={{ margin: "8px 0 0", color: "var(--mhb-muted)" }}>
              {description}
            </p>
          ) : null}
        </div>
        {actions ? (
          <div
            style={{
              display: "flex",
              gap: 8,
              flexWrap: "wrap",
              justifyContent: "flex-end",
            }}
          >
            {actions}
          </div>
        ) : null}
      </header>
      {children}
    </section>
  );
}
