import SwiftUI
import MaohuobanDesignSystem

// PetWalkHistoryDashboardSection 遛弯记录仪表盘区
// 核心职责：
// - 展示月份切换器
// - 展示当前月份累计指标卡片
struct PetWalkHistoryDashboardSection: View {
    let month: PetWalkHistoryMonth
    let summary: PetWalkHistoryMonthlySummary
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s5) {
            PetWalkHistoryMonthSelector(
                monthTitle: month.title,
                onPreviousMonth: onPreviousMonth,
                onNextMonth: onNextMonth
            )

            PetWalkHistoryStatsCard(summary: summary)
        }
    }
}

// PetWalkHistoryMonthSelector 遛弯记录月份切换器
// 核心职责：
// - 展示当前月份标题
// - 承载前后月份切换动作
private struct PetWalkHistoryMonthSelector: View {
    let monthTitle: String
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void

    var body: some View {
        HStack {
            PetWalkHistoryMonthButton(systemImage: "chevron.left", action: onPreviousMonth)

            Spacer()

            Text(monthTitle)
                .font(MHBTheme.Typography.title.weight(.bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer()

            PetWalkHistoryMonthButton(systemImage: "chevron.right", action: onNextMonth)
        }
    }
}

// PetWalkHistoryMonthButton 月份切换按钮
// 核心职责：
// - 提供固定尺寸的月份切换触控区域
// - 保持与记录页浅色圆形按钮一致的视觉
private struct PetWalkHistoryMonthButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background {
            Circle()
                .fill(MHBTheme.ColorToken.cardSolid.color)
        }
        .overlay {
            Circle()
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
    }
}

// PetWalkHistoryStatsCard 遛弯记录统计卡
// 核心职责：
// - 展示当前月份累计里程
// - 展示遛弯次数和总时长
private struct PetWalkHistoryStatsCard: View {
    let summary: PetWalkHistoryMonthlySummary

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 20)
                .frame(width: 120, height: 120)
                .offset(x: 32, y: -36)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text("本月累计里程")
                        .font(MHBTheme.Typography.footnote.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.7))

                    HStack(alignment: .lastTextBaseline, spacing: MHBTheme.Spacing.s1) {
                        Text(summary.distanceText)
                            .font(.system(size: 48, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.white)

                        Text("公里")
                            .font(MHBTheme.Typography.callout.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }

                HStack(spacing: MHBTheme.Spacing.s8) {
                    PetWalkHistoryStatItem(value: "\(summary.walkCount)", label: "遛弯次数")
                    PetWalkHistoryStatItem(value: summary.durationText, label: "总时长")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(MHBTheme.Spacing.s6)
        .background {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraExtraLarge, style: .continuous)
                .fill(MHBTheme.ColorToken.toastBackground.color)
        }
        .shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 12)
    }
}

// PetWalkHistoryStatItem 遛弯统计项
// 核心职责：
// - 展示统计值和标签
// - 统一统计卡内次级指标排版
private struct PetWalkHistoryStatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text(value)
                .font(MHBTheme.Typography.title.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.white)

            Text(label)
                .font(MHBTheme.Typography.section.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.62))
        }
        .frame(minWidth: 0, alignment: .leading)
    }
}
