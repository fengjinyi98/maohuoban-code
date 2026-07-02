import Foundation

// PetPantrySummary 宠物储物柜摘要
// 核心职责：
// - 承载首页展示的储物柜统计信息
// - 提供最后添加日期和物品总数
struct PetPantrySummary: Decodable, Equatable {
    let totalItems: Int
    let lastAddedDate: String

    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items"
        case lastAddedDate = "last_added_date"
    }

    static let mock = PetPantrySummary(
        totalItems: 12,
        lastAddedDate: "2026.06.24"
    )
}
