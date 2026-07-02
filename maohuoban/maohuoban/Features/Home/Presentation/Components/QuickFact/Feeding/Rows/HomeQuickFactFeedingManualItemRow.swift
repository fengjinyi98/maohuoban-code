import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactFeedingManualItemRow 手动喂食占位行
// 核心职责：
// - 为非储物柜物品保留输入位置
// - 引导用户通过备注补充具体内容
struct HomeQuickFactFeedingManualItemRow: View {
    let kind: HomeQuickFactFeedingFoodKind

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: kind.systemImage)
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Text(kind.emptySelectionTitle)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer()
        }
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
    }
}
