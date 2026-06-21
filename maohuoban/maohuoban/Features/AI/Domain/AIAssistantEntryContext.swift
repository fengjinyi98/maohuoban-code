import Foundation

// AIAssistantEntryContext AI 助手入口上下文
// 核心职责：
// - 承载从首页或 UGC 交接进入 AI 助手的最小前端参数
// - 保持路由值可 Hash，便于系统 NavigationStack 推进
struct AIAssistantEntryContext: Hashable {
    let selectedPetID: String?
    let selectedPetName: String?
    let ugcContextTitle: String?

    init(
        selectedPetID: String? = nil,
        selectedPetName: String? = nil,
        ugcContextTitle: String? = nil
    ) {
        self.selectedPetID = selectedPetID
        self.selectedPetName = selectedPetName
        self.ugcContextTitle = ugcContextTitle
    }

    var displayPetName: String {
        guard let selectedPetName, selectedPetName.isEmpty == false else {
            return "当前宠物"
        }
        return selectedPetName
    }
}
