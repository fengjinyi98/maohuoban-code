import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetProfileFactItemView 宠物档案事实项
// 核心职责：
// - 展示单个事实字段的标签和值
// - 统一资料卡中的小型信息层级
struct AIAssistantPetProfileFactItemView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text(label)
                .font(MHBTheme.Typography.caption.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            Text(value)
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
