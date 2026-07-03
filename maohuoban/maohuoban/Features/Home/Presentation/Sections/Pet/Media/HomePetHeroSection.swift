import SwiftUI
import MaohuobanDesignSystem

// HomePetHeroSection 宠物主卡模块
// 核心职责：
// - 展示当前宠物的核心状态和最近动态（以磨砂玻璃卡片形式呈现）
// - 承接进入宠物档案的主入口视觉
struct HomePetHeroSection: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary
    let onOpenWeight: () -> Void
    let onOpenRecordHistory: () -> Void
    let onOpenPantry: () -> Void
    let onOpenPreventiveCare: () -> Void

    var body: some View {
        let stats = pet.stats ?? HomeDashboardSnapshot.PetHeroStats.empty
        let weightDisplay = HomePetHeroWeightDisplay(pet: pet)
        let preventiveCare = HomePetHeroPreventiveCareDisplay(stats: stats)

        HStack(alignment: .center, spacing: 0) {
            // 1. 体重
            Button {
                onOpenWeight()
            } label: {
                HomePetHeroStatColumn(
                    title: "体重",
                    value: weightDisplay.value,
                    unit: "kg",
                    subtitle: weightDisplay.subtitle
                )
                .padding(.leading, MHBTheme.Spacing.s1)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.petHero.weight")

            separator

            // 2. 已记录
            Button {
                onOpenRecordHistory()
            } label: {
                HomePetHeroStatColumn(
                    title: "已记录",
                    value: "\(stats.recordDays)",
                    unit: "天",
                    subtitle: stats.recordStreakText
                )
                .padding(.leading, MHBTheme.Spacing.s3)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.petHero.recordHistory")

            separator

            // 3. 储物柜
            Button {
                onOpenPantry()
            } label: {
                HomePetHeroStatColumn(
                    title: "储物柜",
                    value: "\(stats.pantryItemCount)",
                    unit: "件",
                    subtitle: stats.pantryLastAddedDate
                )
                .padding(.leading, MHBTheme.Spacing.s3)
            }
            .buttonStyle(.plain)

            separator

            // 4. 疫苗/驱虫
            Button {
                onOpenPreventiveCare()
            } label: {
                HomePetHeroStatColumn(
                    title: preventiveCare.title,
                    value: preventiveCare.value,
                    unit: preventiveCare.unit,
                    subtitle: "疫苗/驱虫"
                )
                .padding(.leading, MHBTheme.Spacing.s3)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.petHero.preventiveCare")
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .frame(height: 110)
        .glassEffect(.regular, in: .rect(cornerRadius: MHBTheme.Radius.large))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.petHeroCard")
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 0.5, height: 48)
    }
}

// HomePetHeroPreventiveCareDisplay 预防护理展示模型
// 核心职责：
// - 将疫苗/驱虫最近到期摘要转换为首页 state 卡片文案
// - 在新字段缺失时回退旧驱虫字段，兼容当前后端响应
private struct HomePetHeroPreventiveCareDisplay {
    let title: String
    let value: String
    let unit: String

    init(stats: HomeDashboardSnapshot.PetHeroStats) {
        if let preventiveCare = stats.preventiveCare {
            self.init(preventiveCare: preventiveCare)
        } else {
            self.init(
                title: "距驱虫",
                value: "\(stats.dewormingDaysLeft)",
                unit: "天"
            )
        }
    }

    private init(title: String, value: String, unit: String) {
        self.title = title
        self.value = value
        self.unit = unit
    }

    private init(preventiveCare: HomeDashboardSnapshot.PetHeroStats.PreventiveCareSummary) {
        let name = preventiveCare.kind.displayName
        guard let daysDelta = preventiveCare.daysDelta else {
            self.init(title: name, value: "待补录", unit: "")
            return
        }

        if daysDelta < 0 {
            self.init(title: "\(name)过期", value: "\(abs(daysDelta))", unit: "天")
        } else if daysDelta == 0 {
            self.init(title: name, value: "今日", unit: "")
        } else {
            self.init(title: "距\(name)", value: "\(daysDelta)", unit: "天")
        }
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
