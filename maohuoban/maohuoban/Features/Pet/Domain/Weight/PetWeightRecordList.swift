import Foundation

// PetWeightRecordList 体重记录列表响应
// 核心职责：
// - 承接后端列表接口 data.items 结构
// - 为 Store 一次性替换本地记录提供稳定输入
struct PetWeightRecordList: Decodable, Equatable, Sendable {
    let items: [PetWeightRecord]
}
