import Foundation

// AIAssistantPetProfileSkeletonBlock 宠物档案骨架屏内容块
// 核心职责：
// - 表达后端正在整理宠物档案时的加载占位
// - 避免资料卡在流式回复完成时突兀出现
struct AIAssistantPetProfileSkeletonBlock: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let title: String
}
