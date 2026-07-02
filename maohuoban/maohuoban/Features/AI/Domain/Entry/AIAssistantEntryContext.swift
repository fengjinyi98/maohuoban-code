import Foundation

// AIAssistantEntryContext AI 助手入口上下文
// 核心职责：
// - 承载从首页或 UGC 交接进入 AI 助手的最小前端参数
// - 保持路由值可 Hash，便于系统 NavigationStack 推进
struct AIAssistantEntryContext: Hashable {
    let selectedPetID: String?
    let selectedPetName: String?
    let selectedPetAvatarURL: String?
    let selectedPetSpecies: AIAssistantPetSpecies
    let ugcContextTitle: String?

    init(
        selectedPetID: String? = nil,
        selectedPetName: String? = nil,
        selectedPetAvatarURL: String? = nil,
        selectedPetSpecies: AIAssistantPetSpecies = .other,
        ugcContextTitle: String? = nil
    ) {
        self.selectedPetID = selectedPetID
        self.selectedPetName = selectedPetName
        self.selectedPetAvatarURL = selectedPetAvatarURL
        self.selectedPetSpecies = selectedPetSpecies
        self.ugcContextTitle = ugcContextTitle
    }

    var displayPetName: String {
        guard let selectedPetName, selectedPetName.isEmpty == false else {
            return "当前宠物"
        }
        return selectedPetName
    }
}

// AIAssistantPetSpecies AI 助手宠物物种
// 核心职责：
// - 为 AI 页面头像兜底图标提供稳定物种分类
// - 避免 AI Feature 依赖首页快照模型
enum AIAssistantPetSpecies: Hashable {
    case dog
    case cat
    case other
}
