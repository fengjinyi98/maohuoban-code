import Foundation

// HomePetHeroWeightDisplay 首页体重卡片展示模型
// 核心职责：
// - 将后端体重记录投影转换为首页 state 文案
// - 删除全部体重记录后展示未记录状态
struct HomePetHeroWeightDisplay: Equatable {
    let value: String
    let subtitle: String

    init(pet: HomeDashboardSnapshot.PetHeroSummary) {
        if let stats = pet.stats, !stats.weightVal.isEmpty {
            self.value = stats.weightVal
            self.subtitle = stats.weightChange.isEmpty ? "暂无变化" : stats.weightChange
            return
        }

        self.value = "--"
        self.subtitle = "尚未记录"
    }
}
