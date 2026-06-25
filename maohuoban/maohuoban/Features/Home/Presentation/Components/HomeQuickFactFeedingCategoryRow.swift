import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactFeedingCategoryRow 喂食分类展开行
// 核心职责：
// - 展示喂食分类和当前选中物品
// - 承载互斥展开入口
struct HomeQuickFactFeedingCategoryRow: View {
    let kind: HomeQuickFactFeedingFoodKind
    let selectedItemName: String
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(isExpanded ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelSecondary.color)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(kind.title)
                        .font(MHBTheme.Typography.callout.weight(.bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text(selectedItemName)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .lineLimit(1)
                }

                Spacer(minLength: MHBTheme.Spacing.s2)

                MHBAnimatedDisclosureChevron(
                    isExpanded: isExpanded,
                    size: 12,
                    weight: .bold,
                    color: MHBTheme.ColorToken.labelTertiary.color,
                    systemImage: "chevron.down",
                    expandedRotation: 180
                )
            }
            .padding(MHBTheme.Spacing.s4)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(isExpanded ? MHBTheme.ColorToken.primaryBackgroundSoft.color : MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                    .stroke(isExpanded ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
