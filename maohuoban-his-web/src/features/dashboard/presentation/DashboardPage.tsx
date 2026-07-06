import {
  AlertTriangle,
  ArrowRight,
  CalendarClock,
  CircleDollarSign,
  FileClock,
  Link2,
  Pill,
  Stethoscope,
  Syringe,
} from "lucide-react";
import { Link } from "react-router-dom";
import { HisStatusChip } from "../../../shared/components/HisStatusChip";
import {
  encounterStatusLabels,
  invoiceStatusLabels,
  publicationStatusLabels,
} from "../../../shared/utils/statusLabels";
import { useDashboardViewModel } from "../view-models/useDashboardViewModel";

// DashboardPage 今日工作台
// 核心职责：
// - 展示今日接诊队列和高频状态
// - 提供选中宠物医疗概览和病历入口
export function DashboardPage() {
  const vm = useDashboardViewModel();

  if (vm.isLoading) {
    return <div className="mhb-panel">加载今日队列...</div>;
  }

  if (!vm.data) {
    return <div className="mhb-panel">今日数据加载失败</div>;
  }

  const selectedEncounter =
    vm.data.encounters.find((item) =>
      ["triage", "in_progress"].includes(item.status),
    ) ?? vm.data.encounters[0];
  const pendingInvoices = vm.data.invoices.filter(
    (invoice) => invoice.status === "unpaid",
  );
  const pendingPublications = vm.data.publications.filter(
    (publication) => publication.status !== "published",
  );
  const summary = [
    {
      label: "预约",
      value: vm.data.summary.appointments,
      icon: CalendarClock,
    },
    {
      label: "候诊",
      value: vm.data.summary.pendingEncounter,
      icon: Stethoscope,
    },
    {
      label: "收费",
      value: vm.data.summary.pendingBilling,
      icon: CircleDollarSign,
    },
    { label: "发药", value: vm.data.summary.pendingDispense, icon: Pill },
    {
      label: "发布",
      value: vm.data.summary.pendingPublication,
      icon: FileClock,
    },
  ];

  return (
    <div className="mhb-workbench">
      <section className="mhb-queue-panel">
        <div className="mhb-panel-header">
          <div>
            <h1 className="mhb-panel-title">今日工作台</h1>
            <p>
              医生排班与队列，按到院、接诊、收费、发药和发布状态处理今日任务。
            </p>
          </div>
          <div className="mhb-queue-filters">
            <button className="active" type="button">
              全部
            </button>
            <button type="button">
              候诊中 ({vm.data.summary.pendingEncounter})
            </button>
            <button type="button">
              待收费 ({vm.data.summary.pendingBilling})
            </button>
          </div>
        </div>

        <div className="mhb-mini-metrics">
          {summary.map((item) => {
            const Icon = item.icon;
            return (
              <div className="mhb-mini-metric" key={item.label}>
                <Icon size={16} />
                <span>{item.label}</span>
                <strong>{item.value}</strong>
              </div>
            );
          })}
        </div>

        <div className="mhb-queue-list">
          {vm.data.appointments.map((appointment) => (
            <Link
              className="mhb-patient-card compact"
              key={appointment.id}
              to={`/patients/${appointment.patientId}`}
            >
              <div className="mhb-time-col">{appointment.startsAt}</div>
              <span
                className={`mhb-status-dot ${appointment.status === "arrived" ? "active" : "waiting"}`}
              />
              <div className="mhb-pet-avatar">{appointment.patientName[0]}</div>
              <div className="mhb-patient-info">
                <div>
                  <strong>{appointment.patientName}</strong>
                </div>
                <span>主人：{appointment.ownerName}</span>
              </div>
              <div className="mhb-reason-col">
                <CalendarClock size={14} />
                {appointment.reason}
              </div>
              <HisStatusChip
                tone={appointment.status === "arrived" ? "success" : "info"}
              >
                {appointment.status === "arrived" ? "已到院" : "已预约"}
              </HisStatusChip>
            </Link>
          ))}

          {vm.data.encounters.map((encounter, index) => (
            <Link
              className={`mhb-patient-card${encounter.id === selectedEncounter?.id ? " selected" : ""}`}
              key={encounter.id}
              to={`/encounters/${encounter.id}`}
            >
              <div className="mhb-time-col">
                {index === 0 ? "09:30" : index === 1 ? "10:00" : "10:20"}
              </div>
              <span
                className={`mhb-status-dot ${encounter.status === "in_progress" || encounter.status === "triage" ? "active" : "waiting"}`}
              />
              <div className="mhb-pet-avatar">{encounter.patientName[0]}</div>
              <div className="mhb-patient-info">
                <div>
                  <strong>{encounter.patientName}</strong>
                  {index === 0 ? (
                    <span className="mhb-auth-badge">
                      <Link2 size={11} />
                      含外院授权病史
                    </span>
                  ) : null}
                </div>
                <span>主人：{encounter.ownerName}</span>
              </div>
              <div className="mhb-reason-col">
                <Stethoscope size={14} />
                {encounter.chiefComplaint}
              </div>
              <HisStatusChip
                tone={
                  encounter.status === "pending_dispense"
                    ? "info"
                    : encounter.status === "pending_billing"
                      ? "warning"
                      : "success"
                }
              >
                {encounterStatusLabels[encounter.status]}
              </HisStatusChip>
            </Link>
          ))}

          {pendingInvoices.map((invoice) => (
            <Link
              className="mhb-patient-card compact"
              key={invoice.id}
              to="/billing"
            >
              <div className="mhb-time-col">{invoice.createdAt.slice(11)}</div>
              <span className="mhb-status-dot waiting" />
              <div className="mhb-pet-avatar billing">收</div>
              <div className="mhb-patient-info">
                <div>
                  <strong>{invoice.patientName}</strong>
                </div>
                <span>主人：{invoice.ownerName}</span>
              </div>
              <div className="mhb-reason-col">
                <CircleDollarSign size={14} />
                收费单待处理
              </div>
              <HisStatusChip tone="warning">
                {invoiceStatusLabels[invoice.status]}
              </HisStatusChip>
            </Link>
          ))}

          {pendingPublications.map((publication) => (
            <Link
              className="mhb-patient-card compact"
              key={publication.id}
              to="/health-records"
            >
              <div className="mhb-time-col">待审</div>
              <span className="mhb-status-dot waiting" />
              <div className="mhb-pet-avatar publish">档</div>
              <div className="mhb-patient-info">
                <div>
                  <strong>{publication.patientName}</strong>
                </div>
                <span>健康档案发布审核</span>
              </div>
              <div className="mhb-reason-col">
                <FileClock size={14} />
                App 回流摘要
              </div>
              <HisStatusChip tone="info">
                {publicationStatusLabels[publication.status]}
              </HisStatusChip>
            </Link>
          ))}
        </div>
      </section>

      <aside className="mhb-detail-panel">
        {selectedEncounter ? (
          <>
            <div className="mhb-detail-scroll">
              <div className="mhb-detail-header">
                <div className="mhb-pet-avatar large">
                  {selectedEncounter.patientName[0]}
                </div>
                <div>
                  <h2>{selectedEncounter.patientName}</h2>
                  <p>
                    {selectedEncounter.ownerName} ·{" "}
                    {selectedEncounter.vitals.weightKg}kg
                  </p>
                  <div className="mhb-detail-tags">
                    <span>{selectedEncounter.diagnosis}</span>
                    <span>{selectedEncounter.doctorName}</span>
                  </div>
                </div>
              </div>

              <div className="mhb-alert-block">
                <AlertTriangle size={18} />
                <div>
                  <strong>医疗预警</strong>
                  <p>处方前核对过敏史、当前用药和近期报告，避免重复用药。</p>
                </div>
              </div>

              <section className="mhb-detail-section">
                <div className="mhb-detail-section-title">近期体征</div>
                <div className="mhb-vitals-grid">
                  <div>
                    <span>体重</span>
                    <strong>{selectedEncounter.vitals.weightKg} kg</strong>
                  </div>
                  <div>
                    <span>体温</span>
                    <strong>{selectedEncounter.vitals.temperatureC} ℃</strong>
                  </div>
                  <div>
                    <span>心率</span>
                    <strong>{selectedEncounter.vitals.heartRate}</strong>
                  </div>
                  <div>
                    <span>精神</span>
                    <strong>{selectedEncounter.vitals.spirit}</strong>
                  </div>
                </div>
              </section>

              <section className="mhb-detail-section">
                <div className="mhb-detail-section-title">
                  <span>既往病史摘要</span>
                  <Link to={`/patients/${selectedEncounter.patientId}`}>
                    查看完整档案
                  </Link>
                </div>
                <div className="mhb-history-list">
                  <div className="mhb-history-item">
                    <div className="mhb-history-date">
                      <strong>12</strong>
                      <span>MAY</span>
                    </div>
                    <div>
                      <strong>外院授权病史</strong>
                      <p>宠物主授权后可查看近期病史、当前用药和关键报告。</p>
                      <span>来源可追溯</span>
                    </div>
                  </div>
                  <div className="mhb-history-item">
                    <div className="mhb-history-date">
                      <strong>05</strong>
                      <span>JAN</span>
                    </div>
                    <div>
                      <strong>院内复诊记录</strong>
                      <p>{selectedEncounter.followUpAdvice}</p>
                    </div>
                  </div>
                </div>
              </section>

              <section className="mhb-detail-section">
                <div className="mhb-detail-section-title">风险提醒</div>
                <div className="mhb-risk-list">
                  {vm.data.inventoryRisks.map((risk) => (
                    <Link key={risk.id} to="/pharmacy">
                      <Syringe size={15} />
                      <span>{risk.name}</span>
                      <HisStatusChip
                        tone={
                          risk.status === "low_stock" ? "danger" : "warning"
                        }
                      >
                        {risk.status === "low_stock" ? "低库存" : "近效期"}
                      </HisStatusChip>
                    </Link>
                  ))}
                </div>
              </section>
            </div>

            <div className="mhb-detail-footer">
              <Link
                className="mhb-button primary"
                to={`/encounters/${selectedEncounter.id}`}
              >
                立即进入病历书写
                <ArrowRight size={16} />
              </Link>
            </div>
          </>
        ) : null}
      </aside>
    </div>
  );
}
