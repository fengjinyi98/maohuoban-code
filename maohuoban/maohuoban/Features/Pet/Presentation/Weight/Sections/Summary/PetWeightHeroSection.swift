import SwiftUI
import MaohuobanDesignSystem

// Internal: extracted from PetWeightDetailScreen

// PetWeightHeroCard 当前体重卡片
// 核心职责：
// - 突出展示当前体重数值
// - 展示来自首页 state 的最近变化摘要
struct PetWeightHeroCard: View {
    let currentWeightText: String
    let changeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text("当前记录")
                .font(MHBTheme.Typography.caption.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s1) {
                Text(currentWeightText)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("kg")
                    .font(MHBTheme.Typography.title.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            PetWeightTrendTag(text: normalizedChangeText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var normalizedChangeText: String {
        let trimmedText = changeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? "较上次暂无变化" : trimmedText
    }
}

// PetWeightTrendTag 体重趋势标签
// 核心职责：
// - 以轻量标签展示体重变化
// - 根据文案方向映射趋势颜色
struct PetWeightTrendTag: View {
    let text: String

    private var isIncrease: Bool {
        text.contains("+") || text.contains("增加") || text.contains("上升")
    }

    private var foregroundColor: Color {
        isIncrease ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.success.color
    }

    var body: some View {
        Label(text, systemImage: isIncrease ? "arrow.up" : "arrow.down")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .padding(.vertical, MHBTheme.Spacing.s1)
            .background(foregroundColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
    }
}
