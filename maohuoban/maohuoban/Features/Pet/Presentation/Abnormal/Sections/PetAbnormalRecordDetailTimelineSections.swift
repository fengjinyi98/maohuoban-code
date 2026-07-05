import SwiftUI
import MaohuobanDesignSystem

// PetAbnormalRecordProgressSection 异常事件进展时间线
// 核心职责：
// - 展示当前异常事件下已存在的用户记录和关联记录
// - 用时间线串联异常、观察、就诊和恢复记录
struct PetAbnormalRecordProgressSection: View {
    let records: [PetAbnormalRecordDetailPresentation.RelatedRecord]
    let highlightedRecordID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("进展时间线")
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .textCase(.uppercase)

            if records.isEmpty {
                PetAbnormalRecordProgressEmptyState()
                    .padding(MHBTheme.Spacing.s4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MHBTheme.ColorToken.cardSolid.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
                    .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 10, y: 3)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        PetAbnormalRecordProgressRow(
                            record: record,
                            isCurrent: highlightedRecordID.map { $0 == record.id } ?? record.isCurrentRecord,
                            isFirst: index == 0,
                            isLast: index == records.count - 1
                        )
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
    let isCurrent: Bool
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(record.timeText.replacingOccurrences(of: " ", with: "\n"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.trailing)
                .lineSpacing(2)
                .frame(width: 56, alignment: .trailing)
                .padding(.top, 20)

            PetAbnormalRecordTimelineNode(
                tint: record.kind.tint,
                systemImage: record.kind.systemImage,
                isFirst: isFirst,
                isLast: isLast
            )

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                HStack(spacing: MHBTheme.Spacing.s2) {
                    Text(record.title)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    if isCurrent {
                        Text("当前")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(record.kind.tint)
                            .padding(.horizontal, MHBTheme.Spacing.s2)
                            .padding(.vertical, MHBTheme.Spacing.s1 / 2)
                            .background(record.kind.tint.opacity(0.12), in: Capsule())
                    }

                    if let sourceLabel = record.sourceLabel {
                        PetAbnormalRecordSourceLabelView(title: sourceLabel)
                    }
                }

                Text(record.subtitle)
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)

                if !record.attachmentAssetIDs.isEmpty {
                    PetEventAttachmentDisplayGallery(
                        assetIDs: record.attachmentAssetIDs,
                        thumbnailSize: 64
                    )
                    .padding(.top, MHBTheme.Spacing.s1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MHBTheme.Spacing.s3)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 10, y: 3)
            .padding(.top, 8)
            .padding(.bottom, MHBTheme.Spacing.s4)
        }
    }
}

// PetAbnormalRecordSourceLabelView 异常进展来源标签
// 核心职责：
// - 标识由 Agent 确认写回的异常追加观察
// - 让来源信息跟随对应进展记录展示
private struct PetAbnormalRecordSourceLabelView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .padding(.vertical, MHBTheme.Spacing.s1 / 2)
            .background(MHBTheme.ColorToken.primary.color.opacity(0.12), in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }
}

// PetAbnormalRecordTimelineNode 异常事件时间线节点
// 核心职责：
// - 绘制进展时间线的图标和上下连接线
// - 保持线在图标背后，首尾节点与列表边界对齐
private struct PetAbnormalRecordTimelineNode: View {
    let tint: Color
    let systemImage: String
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                if isFirst && isLast {
                    Color.clear
                } else if isFirst {
                    Color.clear.frame(height: 28)
                    Rectangle().fill(MHBTheme.ColorToken.separatorSoft.color)
                } else if isLast {
                    Rectangle().fill(MHBTheme.ColorToken.separatorSoft.color).frame(height: 28)
                    Color.clear
                } else {
                    Rectangle().fill(MHBTheme.ColorToken.separatorSoft.color)
                }
            }
            .frame(width: 2)

            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: Circle())
                .background(MHBTheme.ColorToken.background.color, in: Circle())
                .padding(.top, 12)
        }
        .frame(width: 48)
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

// PetAbnormalRecordActionSheet 异常事件动作表单
// 核心职责：
// - 承载追加观察和标记恢复的表单输入
// - 通过 PetAbnormalDetailStore 提交真实事件
