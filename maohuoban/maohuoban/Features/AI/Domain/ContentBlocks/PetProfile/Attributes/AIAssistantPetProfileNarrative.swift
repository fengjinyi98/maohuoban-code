import Foundation

// AIAssistantPetProfileNarrative 宠物档案情感文案
// 核心职责：
// - 承载 LLM 基于偏好记忆生成的短文案
// - 只负责表达，不承载事实计算
struct AIAssistantPetProfileNarrative: Decodable, Equatable, Hashable {
    let birth: String?
    let arrival: String?
}
