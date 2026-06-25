import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareRecordDetailScreen 疫苗驱虫记录详情页
// 核心职责：
// - 共用一套详情结构展示疫苗和驱虫记录
// - 只呈现用户主动记录、执行主体、提醒和凭证信息
// - 使用 mock 数据支撑快速 UI 阶段，不接入后端写入
struct PetPreventiveCareRecordDetailScreen: View {
    let recordID: String
    let fallbackKind: PetPreventiveCareKind

    private var presentation: PetPreventiveCareRecordDetailPresentation {
        PetPreventiveCareRecordDetailPresentation.mock(
            recordID: recordID,
            fallbackKind: fallbackKind
        )
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                PetPreventiveCareRecordDetailHeader(presentation: presentation)
                PetPreventiveCareRecordStatusSection(presentation: presentation)
                PetPreventiveCareRecordInfoSection(rows: presentation.infoRows)
                PetPreventiveCareRecordReminderSection(rows: presentation.reminderRows)
                PetPreventiveCareRecordEvidenceSection(
                    note: presentation.note,
                    photoItems: presentation.photoItems
                )
                PetPreventiveCareRelatedRecordsSection(records: presentation.relatedRecords)
                PetPreventiveCareRecordDetailActions()
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s6)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle(presentation.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("pet.preventiveCareRecordDetail.screen")
    }
}

// PetPreventiveCareRecordDetailHeader 疫苗驱虫详情头部
// 核心职责：
// - 展示记录名称、类型图标和宠物身份
// - 让用户快速确认当前记录归属与完成时间
private struct PetPreventiveCareRecordDetailHeader: View {
    let presentation: PetPreventiveCareRecordDetailPresentation

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: presentation.kind.systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(presentation.kind.tint)
                .frame(width: 56, height: 56)
                .background(presentation.kind.tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(presentation.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                HStack(spacing: MHBTheme.Spacing.s2) {
                    MHBAvatar(
                        subject: .pet(presentation.pet.avatarPet),
                        size: .custom(24),
                        shape: .circle
                    )

                    Text("\(presentation.pet.name) · \(presentation.completedAtText)")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
    }
}

// PetPreventiveCareRecordStatusSection 疫苗驱虫提醒状态区
// 核心职责：
// - 突出展示记录状态和下次提醒日期
// - 解释当前记录对首页疫苗驱虫 state 的影响
private struct PetPreventiveCareRecordStatusSection: View {
    let presentation: PetPreventiveCareRecordDetailPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
                Image(systemName: presentation.statusSystemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(presentation.statusTint)
                    .frame(width: 36, height: 36)
                    .background(presentation.statusTint.opacity(0.12), in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(presentation.statusTitle)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(presentation.statusDescription)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: MHBTheme.Spacing.s2)
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 10, y: 3)
    }
}

// PetPreventiveCareRecordInfoSection 疫苗驱虫记录信息区
// 核心职责：
// - 展示类型、名称、完成日期和执行方式
// - 使用键值行保持信息可扫描
private struct PetPreventiveCareRecordInfoSection: View {
    let rows: [PetPreventiveCareRecordDetailPresentation.InfoRow]

    var body: some View {
        PetPreventiveCareRecordDetailSection(title: "记录信息") {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    PetPreventiveCareRecordInfoRow(title: row.title, value: row.value)

                    if row.id != rows.last?.id {
                        PetPreventiveCareRecordDivider()
                    }
                }
            }
        }
    }
}

// PetPreventiveCareRecordReminderSection 疫苗驱虫提醒信息区
// 核心职责：
// - 展示提醒开关状态、提醒日期和距离到期
// - 让用户理解列表与首页到期提示来源
private struct PetPreventiveCareRecordReminderSection: View {
    let rows: [PetPreventiveCareRecordDetailPresentation.InfoRow]

    var body: some View {
        PetPreventiveCareRecordDetailSection(title: "下次提醒") {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    PetPreventiveCareRecordInfoRow(title: row.title, value: row.value)

                    if row.id != rows.last?.id {
                        PetPreventiveCareRecordDivider()
                    }
                }
            }
        }
    }
}

// PetPreventiveCareRecordEvidenceSection 疫苗驱虫备注与照片区
// 核心职责：
// - 展示用户备注和记录凭证
// - 为疫苗本、药盒和医院单据照片预留展示空间
private struct PetPreventiveCareRecordEvidenceSection: View {
    let note: String
    let photoItems: [PetPreventiveCareRecordDetailPresentation.PhotoItem]

    var body: some View {
        PetPreventiveCareRecordDetailSection(title: "备注与照片") {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                Text(note)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: MHBTheme.Spacing.s2) {
                    ForEach(photoItems) { item in
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                            .fill(item.tint.opacity(0.12))
                            .frame(width: 86, height: 86)
                            .overlay {
                                VStack(spacing: MHBTheme.Spacing.s1) {
                                    Image(systemName: item.systemImage)
                                        .font(.system(size: 22, weight: .semibold))

                                    Text(item.title)
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundStyle(item.tint)
                            }
                    }
                }
            }
        }
    }
}

// PetPreventiveCareRelatedRecordsSection 同类预防护理记录区
// 核心职责：
// - 展示当前记录附近的同类历史
// - 帮助用户判断疫苗或驱虫周期是否连续
private struct PetPreventiveCareRelatedRecordsSection: View {
    let records: [PetPreventiveCareRecordDetailPresentation.RelatedRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("同类记录")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            VStack(spacing: 0) {
                ForEach(records) { record in
                    HStack(spacing: MHBTheme.Spacing.s3) {
                        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                            Text(record.title)
                                .font(MHBTheme.Typography.callout.weight(.semibold))
                                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                            Text(record.subtitle)
                                .font(MHBTheme.Typography.caption)
                                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        }

                        Spacer(minLength: MHBTheme.Spacing.s3)

                        Text(record.dateText)
                            .font(MHBTheme.Typography.caption.weight(.medium))
                            .foregroundStyle(record.isCurrent ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelTertiary.color)
                    }
                    .padding(.vertical, MHBTheme.Spacing.s4)

                    if record.id != records.last?.id {
                        PetPreventiveCareRecordDivider()
                    }
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 16, y: 4)
        }
    }
}

// PetPreventiveCareRecordDetailActions 疫苗驱虫详情底部操作
// 核心职责：
// - 保留后续编辑和删除入口
// - 与其他记录详情页保持一致的操作区形态
private struct PetPreventiveCareRecordDetailActions: View {
    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Button("修改记录信息") {}
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(MHBTheme.ColorToken.separatorSoft.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .buttonStyle(.plain)

            Button(role: .destructive) {} label: {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.danger.color)
                    .frame(width: 48, height: 48)
                    .background(MHBTheme.ColorToken.danger.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

// PetPreventiveCareRecordDetailSection 疫苗驱虫详情分组容器
// 核心职责：
// - 统一详情分组标题、卡片和阴影样式
// - 保持疫苗驱虫详情与其他记录详情页一致
private struct PetPreventiveCareRecordDetailSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MHBTheme.Spacing.s4)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
            .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 10, y: 3)
        }
    }
}

// PetPreventiveCareRecordInfoRow 疫苗驱虫详情信息行
// 核心职责：
// - 展示单项记录字段和值
// - 保持右侧长文本可换行展示
private struct PetPreventiveCareRecordInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s4)

            Text(value)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}

// PetPreventiveCareRecordDivider 疫苗驱虫详情分隔线
// 核心职责：
// - 分隔同一卡片内的信息行
// - 使用设计系统柔和分隔色
private struct PetPreventiveCareRecordDivider: View {
    var body: some View {
        Rectangle()
            .fill(MHBTheme.ColorToken.separatorSoft.color)
            .frame(height: 1)
    }
}
