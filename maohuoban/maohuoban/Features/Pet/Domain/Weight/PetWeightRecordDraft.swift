import Foundation

// PetWeightRecordDraft 体重记录写入草稿
// 核心职责：
// - 承载新增和编辑体重记录的请求字段
// - 将前端备注输入映射到后端 note 字段
struct PetWeightRecordDraft: Encodable, Equatable, Sendable {
    let weightGrams: Int
    let note: String?
    let occurredAt: String

    enum CodingKeys: String, CodingKey {
        case weightGrams = "weight_grams"
        case note
        case occurredAt = "occurred_at"
    }
}
