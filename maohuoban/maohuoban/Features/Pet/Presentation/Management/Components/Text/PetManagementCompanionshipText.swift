import SwiftUI
import MaohuobanDesignSystem

// PetManagementCompanionshipText 陪伴天数文本
// 核心职责：
// - 统一展示“陪伴 N 天”的紧凑信息
// - 保持数字在列表行中有稳定强调
struct PetManagementCompanionshipText: View {
    let days: Int

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            Text("陪伴")
            Text("\(days)")
                .font(MHBTheme.Typography.callout)
                .fontWeight(.bold)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Text("天")
        }
        .font(MHBTheme.Typography.caption)
        .fontWeight(.medium)
        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        .lineLimit(1)
    }
}
