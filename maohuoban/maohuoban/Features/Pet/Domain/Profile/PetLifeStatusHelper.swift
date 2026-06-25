import Foundation

// PetLifeStatusHelper 宠物生命状态展示保护
// 核心职责：
// - 判断不同生命状态下允许的操作
// - 去世宠物可查看历史但限制写入
enum PetLifeStatus: String, Decodable, Equatable {
    case alive
    case deceased
    case lost
    case archived
}

extension PetLifeStatus {
    /// 是否允许写入操作（记录日常、健康、体重等）
    var allowsWriteOperations: Bool {
        switch self {
        case .alive, .lost:
            return true
        case .deceased, .archived:
            return false
        }
    }

    /// 是否可查看完整档案（所有状态都可以）
    var allowsViewHistory: Bool {
        true
    }

    /// 展示用中文标签
    var displayLabel: String {
        switch self {
        case .alive: return "健在"
        case .deceased: return "已离世"
        case .lost: return "走失中"
        case .archived: return "已归档"
        }
    }

    /// 是否为终态（不再变更）
    var isTerminal: Bool {
        switch self {
        case .deceased, .archived: return true
        case .alive, .lost: return false
        }
    }
}
