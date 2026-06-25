import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareOverviewSection 疫苗驱虫总览区
// 核心职责：
// - 将最近到期和两类计划组成统一总览
// - 保持总览区与下方历史列表的视觉层级
struct PetPreventiveCareOverviewSection: View {
    let nearestRecord: PetPreventiveCareRecord?
    let vaccineRecord: PetPreventiveCareRecord?
    let dewormingRecord: PetPreventiveCareRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            PetPreventiveCareHeroSection(record: nearestRecord)

            PetPreventiveCarePlanSection(
                vaccineRecord: vaccineRecord,
                dewormingRecord: dewormingRecord
            )
        }
    }
}

// PetPreventiveCareHeroSection 疫苗驱虫顶部状态区
// 核心职责：
// - 解释首页 state 卡片展示的最近到期来源
// - 突出最近需要用户关注的疫苗或驱虫状态
private struct PetPreventiveCareHeroSection: View {
    let record: PetPreventiveCareRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack(alignment: .center) {
                Text("最近到期")
                    .font(MHBTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                Spacer(minLength: MHBTheme.Spacing.s3)

                if let record {
                    PetPreventiveCareStatusTag(record: record)
                }
            }

            if let record {
                HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                    Image(systemName: record.kind.systemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(record.kind.tint)
                        .frame(width: 44, height: 44)
                        .background(record.kind.tint.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                        Text(heroTitle(record: record))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)

                        Text("\(record.title) · \(record.subtitle)")
                            .font(MHBTheme.Typography.callout)
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("待补录")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("补录上次疫苗或驱虫后，这里会显示最近到期事项。")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 14, y: 3)
    }

    private func heroTitle(record: PetPreventiveCareRecord) -> String {
        guard let daysDelta = record.daysDelta else {
            return "待补录"
        }

        if daysDelta < 0 {
            return "\(record.kind.recordTitle)过期 \(abs(daysDelta))天"
        }

        if daysDelta == 0 {
            return "\(record.kind.recordTitle)今日到期"
        }

        return "距\(record.kind.recordTitle) \(daysDelta)天"
    }
}

// PetPreventiveCarePlanSection 疫苗驱虫计划摘要
// 核心职责：
// - 并排展示疫苗和驱虫两条计划状态
// - 帮助用户区分首页最近到期之外的另一类预防护理
struct PetPreventiveCarePlanSection: View {
    let vaccineRecord: PetPreventiveCareRecord?
    let dewormingRecord: PetPreventiveCareRecord?

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            PetPreventiveCarePlanCard(kind: .vaccine, record: vaccineRecord)
            PetPreventiveCarePlanCard(kind: .deworming, record: dewormingRecord)
        }
    }
}

// PetPreventiveCarePlanCard 单项计划卡片
// 核心职责：
// - 展示某一类预防护理的上次记录和下次提醒
// - 在缺失记录时呈现可补录状态
private struct PetPreventiveCarePlanCard: View {
    let kind: PetPreventiveCareKind
    let record: PetPreventiveCareRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Label(kind.recordTitle, systemImage: kind.systemImage)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(kind.tint)

            Text(record?.nextDueText ?? "待补录")
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)

            Text(record.map { "上次 \($0.dateText)" } ?? "补录后生成提醒")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)
        }
        .padding(MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// PetPreventiveCareFilterControl 疫苗驱虫筛选控件
// 核心职责：
// - 在全部、疫苗和驱虫之间切换记录列表
// - 使用系统 segmented 控件保持低学习成本
struct PetPreventiveCareFilterControl: View {
    @Binding var selectedKind: PetPreventiveCareKind

    var body: some View {
        Picker("记录类型", selection: $selectedKind) {
            ForEach(PetPreventiveCareKind.allCases) { kind in
                Text(kind.title).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("pet.preventiveCare.filter")
    }
}

// PetPreventiveCareHistorySection 疫苗驱虫历史记录区
// 核心职责：
// - 按月份展示疫苗和驱虫历史记录
// - 为后续记录详情推进保留点击入口
struct PetPreventiveCareHistorySection: View {
    let groups: [PetPreventiveCareHistoryGroup]
    let onOpenRecord: (PetPreventiveCareRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("历史记录")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            if groups.isEmpty {
                PetPreventiveCareEmptyHistory()
            } else {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                    ForEach(groups) { group in
                        PetPreventiveCareHistoryMonthGroup(
                            group: group,
                            onOpenRecord: onOpenRecord
                        )
                    }
                }
            }
        }
    }
}

// PetPreventiveCareHistoryMonthGroup 疫苗驱虫月份分组
// 核心职责：
// - 展示单个月份下的预防护理记录
// - 让月份和年份在滚动列表中保持清晰上下文
private struct PetPreventiveCareHistoryMonthGroup: View {
    let group: PetPreventiveCareHistoryGroup
    let onOpenRecord: (PetPreventiveCareRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            HStack(alignment: .bottom) {
                Text(group.month)
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                Spacer()

                Text(group.year)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }

            VStack(spacing: MHBTheme.Spacing.s2) {
                ForEach(group.records) { record in
                    Button {
                        onOpenRecord(record)
                    } label: {
                        PetPreventiveCareHistoryRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// PetPreventiveCareHistoryRow 疫苗驱虫历史记录行
// 核心职责：
// - 展示单条记录的类型、名称、提醒和日期
// - 保留右侧箭头表达可进入详情
private struct PetPreventiveCareHistoryRow: View {
    let record: PetPreventiveCareRecord

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: record.kind.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(record.kind.tint)
                .frame(width: 34, height: 34)
                .background(record.kind.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(record.title)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(record.subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }

            Spacer(minLength: MHBTheme.Spacing.s3)

            VStack(alignment: .trailing, spacing: MHBTheme.Spacing.s1 / 2) {
                Text(record.dateText)
                    .font(MHBTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                if let nextDueText = record.nextDueText {
                    Text("下次 \(nextDueText)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(record.status.tint)
                        .lineLimit(1)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 14, y: 3)
        .contentShape(Rectangle())
    }
}

// PetPreventiveCareStatusTag 疫苗驱虫状态标签
// 核心职责：
// - 展示最近到期记录的提醒日期和状态
// - 用颜色区分正常、临期和过期
private struct PetPreventiveCareStatusTag: View {
    let record: PetPreventiveCareRecord

    var body: some View {
        Label(statusText, systemImage: "bell.badge")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(record.status.tint)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .padding(.vertical, MHBTheme.Spacing.s1)
            .background(record.status.tint.opacity(0.12), in: Capsule())
    }

    private var statusText: String {
        if let nextDueText = record.nextDueText {
            return "\(record.status.title) · \(nextDueText)"
        }

        return record.status.title
    }
}

// PetPreventiveCareEmptyHistory 疫苗驱虫空记录
// 核心职责：
// - 在筛选后无记录时给出补录提示
// - 保持页面空态不影响整体布局
private struct PetPreventiveCareEmptyHistory: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text("暂无记录")
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("新增疫苗或驱虫记录后，会在这里按月份展示。")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .padding(MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}
