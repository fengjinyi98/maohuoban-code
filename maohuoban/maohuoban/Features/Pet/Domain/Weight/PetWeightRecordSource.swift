import Foundation

// PetWeightRecordSource 体重记录来源
// 核心职责：
// - 区分创建宠物时生成的初始体重和用户手动记录
// - 保留未知来源以兼容后端后续扩展
enum PetWeightRecordSource: String, Decodable, Equatable, Sendable {
    case profileInitial = "profile_initial"
    case manual
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = PetWeightRecordSource(rawValue: rawValue) ?? .unknown
    }
}
