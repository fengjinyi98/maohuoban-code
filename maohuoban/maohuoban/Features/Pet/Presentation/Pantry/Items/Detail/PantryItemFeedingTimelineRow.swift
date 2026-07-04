import SwiftUI
import MaohuobanDesignSystem

// PantryItemFeedingTimelineRow 物品喂食时间线行
// 核心职责：
// - 展示单条喂食事件标题、宠物和份量
// - 保持时间线行与首页记录风格接近
struct PantryItemFeedingTimelineRow: View {
    let entry: FoodInventoryFeedingTimelineEntry

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "fork.knife")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(mhbHex: "0093DD"))
                .frame(width: 36, height: 36)
                .background(Color(mhbHex: "0093DD").opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(entry.title)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                Text("\(entry.petName) · \(entry.amountText)")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)

                if let summary = entry.summary, !summary.isEmpty {
                    Text(summary)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
