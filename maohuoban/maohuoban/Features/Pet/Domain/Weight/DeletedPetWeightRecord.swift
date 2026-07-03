import Foundation

// DeletedPetWeightRecord 体重记录删除结果
// 核心职责：
// - 承接后端软删除确认结果
// - 让 Store 根据 record id 移除本地展示项
struct DeletedPetWeightRecord: Decodable, Equatable, Sendable {
    let id: String
    let deleted: Bool
}
