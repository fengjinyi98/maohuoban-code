import Foundation

// AIAssistantReferenceSourcePresentation AI 引用来源展示模型
// 核心职责：
// - 将后端引用类型映射为用户可读来源
// - 将引用标签拆解为 sheet 列表主副标题
struct AIAssistantReferenceSourcePresentation: Hashable, Identifiable {
    let reference: AIAssistantReference
    let sourceTitle: String
    let systemImage: String
    let title: String
    let subtitle: String?
    let isNavigable: Bool

    var id: String { reference.id }

    init(reference: AIAssistantReference) {
        self.reference = reference

        let rawTitle = reference.normalizedTitle
        let rawSubtitle = reference.normalizedSubtitle

        switch reference.sourceKind {
        case "pet_event":
            sourceTitle = "日常记录"
            systemImage = "calendar.badge.clock"
            title = rawTitle.isEmpty ? "日常记录" : rawTitle
            subtitle = rawSubtitle
            isNavigable = true
        case "diet_assignment":
            sourceTitle = "当前主粮"
            systemImage = "takeoutbag.and.cup.and.straw.fill"
            title = rawSubtitle ?? rawTitle
            subtitle = rawSubtitle == nil ? nil : "主粮"
            isNavigable = false
        default:
            sourceTitle = "引用来源"
            systemImage = "link"
            title = rawTitle.isEmpty ? reference.label : rawTitle
            subtitle = rawSubtitle
            isNavigable = false
        }
    }
}
