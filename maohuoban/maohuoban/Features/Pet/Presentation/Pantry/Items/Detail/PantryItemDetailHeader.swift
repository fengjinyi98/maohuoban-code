import SwiftUI
import MaohuobanDesignSystem

// PantryItemDetailHeader 物品详情头部
// 核心职责：
// - 展示物品封面、名称、品牌、分类和库存状态
// - 作为详情页首屏识别区域
struct PantryItemDetailHeader: View {
    let item: FoodInventoryItem

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s4) {
            PantryItemDetailCover(imageURLString: item.coverURL)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(item.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(2)

                Text(subtitle)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)

                HStack(spacing: MHBTheme.Spacing.s2) {
                    Text(item.inventoryStatus.pantryDetailDisplayText)
                        .font(MHBTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .padding(.vertical, MHBTheme.Spacing.s1)
                        .background(MHBTheme.ColorToken.separatorSoft.color)
                        .clipShape(Capsule())

                    Text("剩余 \(item.quantity) \(item.unit ?? "件")")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }

    private var subtitle: String {
        let brand = item.brand?.isEmpty == false ? item.brand ?? "未填写品牌" : "未填写品牌"
        let spec = item.spec?.isEmpty == false ? item.spec ?? "默认规格" : "默认规格"
        return "\(brand) · \(item.category.pantryDetailDisplayText) · \(spec)"
    }
}
