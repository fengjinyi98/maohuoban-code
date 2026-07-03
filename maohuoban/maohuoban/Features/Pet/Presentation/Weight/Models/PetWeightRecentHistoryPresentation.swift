import Foundation

// PetWeightRecentHistoryPresentation 体重近期记录展示模型
// 核心职责：
// - 限定体重详情页近期记录展示数量
// - 根据完整记录数量决定是否展示完整历史入口
struct PetWeightRecentHistoryPresentation: Equatable {
    let records: [PetWeightRecord]
    let showsFullHistoryEntry: Bool

    init(records: [PetWeightRecord], displayLimit: Int = 4) {
        self.records = Array(records.prefix(displayLimit))
        self.showsFullHistoryEntry = records.count > displayLimit
    }
}
