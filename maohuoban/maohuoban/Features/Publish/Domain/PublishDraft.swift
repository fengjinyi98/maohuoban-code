import Foundation

// PublishDraft 图文发布草稿
// 核心职责：
// - 作为发布页本地状态的领域快照
// - 统一承载宠物、事件类型、正文、话题、地点和可见范围
struct PublishDraft: Equatable, Sendable {
    var title: String
    var bodyText: String
    var selectedPetID: String?
    var selectedPetName: String?
    var eventType: PublishEventType
    var visibility: PublishVisibility
    var city: String?
    var localEntityID: String?
    var localEntityName: String?
    var location: PublishLocation?
    var topicNames: [String]
    var mediaCount: Int

    init(context: PublishEntryContext) {
        self.title = ""
        self.bodyText = ""
        self.selectedPetID = context.selectedPetID
        self.selectedPetName = context.selectedPetName
        self.eventType = context.source.defaultEventType
        self.visibility = .publicVisible
        self.city = context.city
        self.localEntityID = context.localEntityID
        self.localEntityName = context.localEntityName
        self.location = Self.makeLocation(
            city: context.city,
            localEntityName: context.localEntityName
        )
        self.topicNames = context.seedTopicName.map { [$0] } ?? []
        self.mediaCount = 0
    }

    private static func makeLocation(
        city: String?,
        localEntityName: String?
    ) -> PublishLocation? {
        let displayName = [
            localEntityName,
            city,
        ]
        .compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }
        .first

        guard let displayName else {
            return nil
        }

        return PublishLocation(
            displayName: displayName,
            poiName: localEntityName,
            city: city
        )
    }
}

// PublishDraftPhase 发布草稿阶段
// 核心职责：
// - 表达本地草稿是否已经完成前端提交
// - 为页面反馈区域提供单一状态来源
enum PublishDraftPhase: Equatable, Sendable {
    case idle
    case prepared
}
