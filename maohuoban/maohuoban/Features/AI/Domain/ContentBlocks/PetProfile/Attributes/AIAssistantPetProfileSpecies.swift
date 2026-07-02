import Foundation
import MaohuobanDesignSystem

// AIAssistantPetProfileSpecies 宠物资料卡物种
// 核心职责：
// - 约束后端返回的宠物物种枚举
// - 为头像缺省态提供稳定图标语义
enum AIAssistantPetProfileSpecies: String, Decodable, Equatable, Hashable {
    case dog
    case cat
    case other

    var avatarSpecies: MHBAvatarSpecies {
        switch self {
        case .dog:
            .dog
        case .cat:
            .cat
        case .other:
            .other
        }
    }
}
