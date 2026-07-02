import SwiftUI
import MaohuobanDesignSystem

// PantryCategoryCard 储物柜分类卡片
// 核心职责：
// - 展示分类封面、名称和物品数量
// - 复刻相册叠放视觉效果
struct PantryCategoryCard: View {
    let category: PantryCategory
    let count: Int
    let coverImageURL: String?
    let customTitle: String?
    let isPinned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            PantryCategoryCover(imageURL: coverImageURL, isPinned: isPinned)

            VStack(alignment: .leading, spacing: 2) {
                if let customTitle = customTitle {
                    Text(customTitle)
                        .font(MHBTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text("\(category.displayName) · \(count) 件物品")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                } else {
                    Text(category.displayName)
                        .font(MHBTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text("\(count) 件物品")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
