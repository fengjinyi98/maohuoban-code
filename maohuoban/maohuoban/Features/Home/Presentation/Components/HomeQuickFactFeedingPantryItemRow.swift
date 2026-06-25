import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactFeedingPantryItemRow 喂食储物柜物品行
// 核心职责：
// - 展示储物柜物品名称、品牌和状态
// - 提供具体喂食物品选中态
struct HomeQuickFactFeedingPantryItemRow: View {
    let item: HomeQuickFactFeedingFoodOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                HomeQuickFactFeedingPantryThumbnail(item: item)

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(item.name)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text("\(item.displayBrand) · \(item.statusLabel)")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .lineLimit(1)
                }

                Spacer(minLength: MHBTheme.Spacing.s2)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color)
            }
            .padding(MHBTheme.Spacing.s3)
            .background(isSelected ? MHBTheme.ColorToken.primaryBackgroundSoft.color : MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .stroke(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
