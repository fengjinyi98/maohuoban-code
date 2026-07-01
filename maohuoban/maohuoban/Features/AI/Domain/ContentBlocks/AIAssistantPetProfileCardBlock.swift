import Foundation

// AIAssistantPetProfileCardBlock 宠物档案资料卡内容块
// 核心职责：
// - 承载宠物事实字段、确定性计算结果和 LLM 情感文案
// - 为 AI 回复中的宠物资料 UI 提供稳定渲染契约
struct AIAssistantPetProfileCardBlock: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let pet: AIAssistantPetProfileFact
    let computed: AIAssistantPetProfileComputed
    let narrative: AIAssistantPetProfileNarrative
}
