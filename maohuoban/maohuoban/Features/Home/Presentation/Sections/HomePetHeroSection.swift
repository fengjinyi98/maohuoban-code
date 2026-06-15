import SwiftUI
import MaohuobanDesignSystem

// HomePetHeroSection 宠物主卡模块
// 核心职责：
// - 展示当前宠物的核心状态和最近动态（以磨砂玻璃卡片形式呈现）
// - 承接进入宠物档案的主入口视觉
struct HomePetHeroSection: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s4) {
            // 左侧：核心指标与动态信息
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text("\(pet.ageText) · \(pet.breed)")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                Text(pet.statusText)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pet.updatedText)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }

            Spacer()

            // 右侧：查看档案操作入口
            HStack(spacing: MHBTheme.Spacing.s1) {
                Text("查看档案")
                    .font(MHBTheme.Typography.footnote)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 14))
            }
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .padding(.vertical, MHBTheme.Spacing.s2)
            .background {
                Capsule()
                    .fill(MHBTheme.ColorToken.primaryBackground.color)
            }
            .overlay {
                Capsule()
                    .stroke(MHBTheme.ColorToken.primary.color.opacity(0.3), lineWidth: 1)
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .frame(height: 110) // 较之前的 160 高度更加紧凑，匹配无头像卡片比例
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.petHeroCard")
    }
}
