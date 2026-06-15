import SwiftUI
import MaohuobanDesignSystem

// HomePetHeroSection 宠物主卡模块
// 核心职责：
// - 展示当前宠物的核心状态和最近动态（以磨砂玻璃卡片形式呈现）
// - 承接进入宠物档案的主入口视觉
struct HomePetHeroSection: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary

    var body: some View {
        let stats = pet.stats ?? HomeDashboardSnapshot.PetHeroStats.mock

        HStack(alignment: .center, spacing: 0) {
            // 1. 体重
            HomePetHeroStatColumn(
                title: "体重",
                value: stats.weightVal,
                unit: "kg",
                subtitle: stats.weightChange
            )
            .padding(.leading, MHBTheme.Spacing.s1)

            separator

            // 2. 已记录
            HomePetHeroStatColumn(
                title: "已记录",
                value: "\(stats.recordDays)",
                unit: "天",
                subtitle: stats.recordStreakText
            )
            .padding(.leading, MHBTheme.Spacing.s3)

            separator

            // 3. 距疫苗
            HomePetHeroStatColumn(
                title: "距疫苗",
                value: "\(stats.vaccineDaysLeft)",
                unit: "天",
                subtitle: stats.vaccineDate
            )
            .padding(.leading, MHBTheme.Spacing.s3)

            separator

            // 4. 距驱虫
            HomePetHeroStatColumn(
                title: "距驱虫",
                value: "\(stats.dewormingDaysLeft)",
                unit: "天",
                subtitle: stats.dewormingDate
            )
            .padding(.leading, MHBTheme.Spacing.s3)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .frame(height: 110)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.petHeroCard")
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 0.5, height: 48)
    }
}

// HomePetHeroStatColumn 单个指标列组件
private struct HomePetHeroStatColumn: View {
    let title: String
    let value: String
    let unit: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Text(subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
