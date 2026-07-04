import Foundation

// DeletedPetEvent 宠物事件删除结果
// 核心职责：
// - 表达后端事件删除成功后的最小响应
// - 为详情页移除当前记录提供稳定判断
struct DeletedPetEvent: Decodable, Equatable, Sendable {
    let id: String
    let deleted: Bool
}
