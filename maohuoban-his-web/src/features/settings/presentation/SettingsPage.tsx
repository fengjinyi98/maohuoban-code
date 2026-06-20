import { HisPageShell } from "../../../shared/components/HisPageShell";
import { HisStatusChip } from "../../../shared/components/HisStatusChip";
import { roleLabels } from "../../../shared/permissions/permissions";
import { useSettingsViewModel } from "../view-models/useSettingsViewModel";

// SettingsPage 设置页
// 核心职责：
// - 展示员工独立账号、角色、院区和药品配置
// - 呈现院长管理员授权边界
export function SettingsPage() {
  const vm = useSettingsViewModel();

  return (
    <HisPageShell
      title="设置"
      description="院长和管理员维护员工、角色、院区、项目、药品和病历模板。"
    >
      <section className="mhb-card">
        <h2 style={{ marginTop: 0 }}>员工管理</h2>
        <div className="mhb-table-wrap">
          <table className="mhb-table">
            <thead>
              <tr>
                <th>员工</th>
                <th>账号</th>
                <th>角色</th>
                <th>院区</th>
                <th>状态</th>
              </tr>
            </thead>
            <tbody>
              {vm.data?.members.map((member) => (
                <tr key={member.id}>
                  <td>{member.name}</td>
                  <td>{member.account}</td>
                  <td>{roleLabels[member.role]}</td>
                  <td>{member.siteIds.join("、")}</td>
                  <td>
                    <HisStatusChip tone={member.enabled ? "success" : "danger"}>
                      {member.enabled ? "启用" : "停用"}
                    </HisStatusChip>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <div className="mhb-grid mhb-grid-2">
        <section className="mhb-card">
          <h2 style={{ marginTop: 0 }}>院区管理</h2>
          {vm.data?.sites.map((site) => (
            <p key={site.id}>
              {site.name} · {site.city}
            </p>
          ))}
        </section>
        <section className="mhb-card">
          <h2 style={{ marginTop: 0 }}>病历模板</h2>
          <p>常用主诉：呕吐、腹泻、精神下降、年度免疫。</p>
          <p>常用处方模板：抗生素、止吐、驱虫、慢病复诊。</p>
        </section>
      </div>
    </HisPageShell>
  );
}
