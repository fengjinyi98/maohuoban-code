import Foundation

// PantryStatus 储物柜物品状态
// 核心职责：
// - 表达物品当前使用状态
// - 支持标签样式区分
enum PantryStatus: String, Decodable, Equatable {
    case inUse = "in_use"
    case sealed = "sealed"
    case periodic = "periodic"

    var isGrayTag: Bool {
        self == .sealed || self == .periodic
    }
}
