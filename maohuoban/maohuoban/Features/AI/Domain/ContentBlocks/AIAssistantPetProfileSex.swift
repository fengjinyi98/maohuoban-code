import Foundation
import MaohuobanDesignSystem

// AIAssistantPetProfileSex 宠物资料卡性别
// 核心职责：
// - 约束后端返回的宠物性别枚举
// - 为头像和标签提供稳定性别语义
enum AIAssistantPetProfileSex: String, Decodable, Equatable, Hashable {
    case male
    case female
    case unknown

    var avatarSex: MHBAvatarSex {
        switch self {
        case .male:
            .male
        case .female:
            .female
        case .unknown:
            .unknown
        }
    }
}
