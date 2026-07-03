import Foundation

// HomePetHeroWeightDisplay 首页体重卡片展示模型
// 核心职责：
// - 将后端 stats 或宠物档案体重转换为首页 state 文案
// - 移除体重卡片对 mock stats 的依赖
struct HomePetHeroWeightDisplay: Equatable {
    let value: String
    let subtitle: String

    init(pet: HomeDashboardSnapshot.PetHeroSummary) {
        if let stats = pet.stats, !stats.weightVal.isEmpty {
            self.value = stats.weightVal
            self.subtitle = stats.weightChange.isEmpty ? "暂无变化" : stats.weightChange
            return
        }

        if let weightGrams = pet.weightGrams {
            self.value = String(format: "%.2f", Double(weightGrams) / 1000)
            self.subtitle = "初始体重"
            return
        }

        self.value = "--"
        self.subtitle = "尚未记录"
    }
}
