import SwiftUI
import MaohuobanDesignSystem

// PetPantryDietSummarySection 储物柜饮食摘要区
// 核心职责：
// - 在空间级储物柜首页展示当前宠物饮食配置摘要
// - 区分食品资产归属和宠物消费配置
struct PetPantryDietSummarySection: View {
    let petName: String
    let rows: [PetPantryDietSummaryRow]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text("\(petName)的饮食配置")
                    .font(MHBTheme.Typography.headline.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("食品资产归家庭共享，饮食配置记录这只宠物正在吃什么")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            if rows.isEmpty {
                PetPantryDietEmptySummaryRow()
            } else {
                ForEach(rows) { row in
                    PetPantryDietSummaryRowView(title: row.title, value: row.value)
                }
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
    }

    // PetPantryDietSummaryRowView 饮食摘要单行
    // 核心职责：
    // - 展示一个饮食角色和对应食品名称
    // - 控制长食品名称的截断方式
    private struct PetPantryDietSummaryRowView: View {
        let title: String
        let value: String

        var body: some View {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Text(title)
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .padding(.horizontal, MHBTheme.Spacing.s2)
                    .padding(.vertical, MHBTheme.Spacing.s1)
                    .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                    .clipShape(Capsule())

                Text(value)
                    .font(MHBTheme.Typography.callout.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
        }
    }

    // PetPantryDietEmptySummaryRow 空饮食配置提示
    // 核心职责：
    // - 在没有饮食配置时提供轻量空态
    // - 引导用户理解储物柜资产和宠物配置尚未绑定
    private struct PetPantryDietEmptySummaryRow: View {
        var body: some View {
            Text("还未设置当前主粮或尝试中食品")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, MHBTheme.Spacing.s2)
        }
    }
}
