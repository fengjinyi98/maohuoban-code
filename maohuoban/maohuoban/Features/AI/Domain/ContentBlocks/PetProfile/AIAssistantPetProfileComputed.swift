import Foundation

// AIAssistantPetProfileComputed 宠物档案确定性计算字段
// 核心职责：
// - 承载后端计算出的年龄和陪伴时长
// - 防止 LLM 在日期计算中产生事实错误
struct AIAssistantPetProfileComputed: Decodable, Equatable, Hashable {
    let ageText: String?
    let companionshipText: String?

    enum CodingKeys: String, CodingKey {
        case ageText = "age_text"
        case companionshipText = "companionship_text"
    }
}
