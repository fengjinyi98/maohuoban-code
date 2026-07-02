import Foundation

// PetNameEditPolicy 宠物名字编辑策略
// 核心职责：
// - 承接后端计算出的宠物改名额度
// - 为编辑页名字弹层提供展示文案
nonisolated struct PetNameEditPolicy: Decodable, Equatable, Hashable {
    let maxCount: Int
    let usedCount: Int
    let remainingCount: Int
    let windowDays: Int
    let windowEndsAt: String?
    let displayText: String

    enum CodingKeys: String, CodingKey {
        case maxCount = "max_count"
        case usedCount = "used_count"
        case remainingCount = "remaining_count"
        case windowDays = "window_days"
        case windowEndsAt = "window_ends_at"
        case displayText = "display_text"
    }
}
