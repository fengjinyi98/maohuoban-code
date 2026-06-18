import Foundation

// DeletePetProfileDraft 删除宠物档案草稿
// 核心职责：
// - 承载软删除原因
// - 与后端恢复窗口设计保持请求契约稳定
struct DeletePetProfileDraft: Encodable, Equatable {
    let reason: String
}
