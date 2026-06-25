import SwiftUI
import MaohuobanDesignSystem

// PetAbnormalRecordDetailSheet 异常详情弹层状态
// 核心职责：
// - 统一承载异常详情页内的临时 sheet 入口
// - 避免多个 sheet 状态在同一页面互相抢占
enum PetAbnormalRecordDetailSheet: Identifiable {
    case action(PetAbnormalRecordDetailAction)
    case relatedRecord(PetAbnormalRecordDetailPresentation.RelatedRecord)

    var id: String {
        switch self {
        case .action(let action):
            "action-\(action.id)"
        case .relatedRecord(let record):
            "related-\(record.id)"
        }
    }
}

// PetAbnormalRecordDetailAction 异常事件追加动作
// 核心职责：
// - 定义异常详情页可追加的用户记录入口
// - 保持动作只创建或关联记录，不生成 AI/LLM 建议
enum PetAbnormalRecordDetailAction: String, CaseIterable, Identifiable {
    case addObservation
    case linkClinicVisit
    case markRecovered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addObservation: "追加观察"
        case .linkClinicVisit: "关联就诊"
        case .markRecovered: "标记恢复"
        }
    }

    var subtitle: String {
        switch self {
        case .addObservation:
            "补充后续状态、照片或备注"
        case .linkClinicVisit:
            "把就诊记录挂到这次异常下"
        case .markRecovered:
            "记录恢复时间和恢复表现"
        }
    }

    var systemImage: String {
        switch self {
        case .addObservation: "plus.bubble.fill"
        case .linkClinicVisit: "stethoscope"
        case .markRecovered: "checkmark.seal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .addObservation:
            MHBTheme.ColorToken.warning.color
        case .linkClinicVisit:
            MHBTheme.ColorToken.primary.color
        case .markRecovered:
            MHBTheme.ColorToken.success.color
        }
    }

    var flowDescription: String {
        switch self {
        case .addObservation:
            "后续会打开追加观察表单，生成一条新的观察记录，并自动挂到当前异常事件时间线。"
        case .linkClinicVisit:
            "后续会进入就诊记录选择或新增流程，保存后把就诊记录关联到当前异常事件。"
        case .markRecovered:
            "后续会打开恢复记录表单，记录恢复时间、状态和备注，并作为事件结束节点。"
        }
    }
}

// PetAbnormalRecordProgressSection 异常事件进展时间线
// 核心职责：
// - 展示当前异常事件下已存在的用户记录和关联记录
// - 用时间线串联异常、观察、就诊和恢复记录
struct PetAbnormalRecordProgressSection: View {
    let records: [PetAbnormalRecordDetailPresentation.RelatedRecord]
    let onOpenRecord: (PetAbnormalRecordDetailPresentation.RelatedRecord) -> Void

    var body: some View {
        PetAbnormalRecordDetailSection(title: "进展时间线") {
            if records.isEmpty {
                PetAbnormalRecordProgressEmptyState()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        Button {
                            onOpenRecord(record)
                        } label: {
                            PetAbnormalRecordProgressRow(
                                record: record,
                                isFirst: index == 0,
                                isLast: index == records.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// PetAbnormalRecordProgressRow 异常事件时间线行
// 核心职责：
// - 展示一条关联记录的时间、类型和摘要
// - 保持当前原始异常记录和后续记录的层级差异
private struct PetAbnormalRecordProgressRow: View {
    let record: PetAbnormalRecordDetailPresentation.RelatedRecord
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            Text(record.timeText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .frame(width: 74, alignment: .trailing)

            PetAbnormalRecordProgressLine(
                tint: record.kind.tint,
                isFirst: isFirst,
                isLast: isLast
            )

            Image(systemName: record.kind.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(record.kind.tint)
                .frame(width: 36, height: 36)
                .background(record.kind.tint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                HStack(spacing: MHBTheme.Spacing.s2) {
                    Text(record.title)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    if record.isCurrentRecord {
                        Text("当前")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(record.kind.tint)
                            .padding(.horizontal, MHBTheme.Spacing.s2)
                            .padding(.vertical, MHBTheme.Spacing.s1 / 2)
                            .background(record.kind.tint.opacity(0.10), in: Capsule())
                    }
                }

                Text(record.subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
        .contentShape(Rectangle())
    }
}

// PetAbnormalRecordProgressLine 异常事件时间线连接线
// 核心职责：
// - 绘制进展时间线的节点和上下连接
// - 保持首尾节点与列表边界对齐
private struct PetAbnormalRecordProgressLine: View {
    let tint: Color
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if isFirst {
                    Color.clear
                } else {
                    Rectangle().fill(MHBTheme.ColorToken.separatorSoft.color)
                }

                if isLast {
                    Color.clear
                } else {
                    Rectangle().fill(MHBTheme.ColorToken.separatorSoft.color)
                }
            }
            .frame(width: 1)

            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
        }
        .frame(width: 12)
    }
}

// PetAbnormalRecordProgressEmptyState 异常事件空时间线
// 核心职责：
// - 表达当前异常事件尚未挂载后续记录
// - 保持空态为记录状态，不提供处理建议
private struct PetAbnormalRecordProgressEmptyState: View {
    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "clock")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text("暂无后续记录")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// PetAbnormalRecordEpisodeActions 异常事件追加入口
// 核心职责：
// - 提供追加观察、关联就诊和标记恢复入口
// - 让异常事件后续通过记录串联，而不是通过建议文案串联
struct PetAbnormalRecordEpisodeActions: View {
    let onSelectAction: (PetAbnormalRecordDetailAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("追加记录")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            VStack(spacing: MHBTheme.Spacing.s2) {
                ForEach(PetAbnormalRecordDetailAction.allCases) { action in
                    Button {
                        onSelectAction(action)
                    } label: {
                        PetAbnormalRecordEpisodeActionRow(action: action)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// PetAbnormalRecordEpisodeActionRow 异常事件追加入口行
// 核心职责：
// - 展示一个可追加或关联的记录动作
// - 保持记录入口与详情内容分层
private struct PetAbnormalRecordEpisodeActionRow: View {
    let action: PetAbnormalRecordDetailAction

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: action.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(action.tint)
                .frame(width: 40, height: 40)
                .background(action.tint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(action.title)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(action.subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s3)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 10, y: 3)
        .contentShape(Rectangle())
    }
}

// PetAbnormalRecordActionSheet 异常事件动作占位弹层
// 核心职责：
// - 在快速 UI 阶段展示追加记录动作的流程边界
// - 后续接入真实表单或路由时替换为对应业务流程
struct PetAbnormalRecordActionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let action: PetAbnormalRecordDetailAction

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(action.tint)
                    .frame(width: 64, height: 64)
                    .background(action.tint.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    Text(action.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(action.flowDescription)
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button("知道了") {
                    dismiss()
                }
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(MHBTheme.ColorToken.primary.color, in: Capsule())
                .buttonStyle(.plain)
            }
            .padding(MHBTheme.Spacing.s5)
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle(action.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// PetAbnormalRecordRelatedRecordSheet 异常事件关联记录预览
// 核心职责：
// - 在快速 UI 阶段展示关联记录点击后的目标形态
// - 后续接入真实详情页后替换为对应记录路由
struct PetAbnormalRecordRelatedRecordSheet: View {
    @Environment(\.dismiss) private var dismiss

    let record: PetAbnormalRecordDetailPresentation.RelatedRecord

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                Image(systemName: record.kind.systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(record.kind.tint)
                    .frame(width: 64, height: 64)
                    .background(record.kind.tint.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    Text(record.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(record.timeText)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                    Text(record.subtitle)
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button("关闭") {
                    dismiss()
                }
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(MHBTheme.ColorToken.primary.color, in: Capsule())
                .buttonStyle(.plain)
            }
            .padding(MHBTheme.Spacing.s5)
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle(record.kind.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
