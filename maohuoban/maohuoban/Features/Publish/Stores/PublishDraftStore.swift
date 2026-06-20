import Foundation
import Observation

// PublishDraftStore 图文发布草稿状态模型
// 核心职责：
// - 管理图文发布页的本地草稿状态
// - 提供发布按钮启用判断和本地提交反馈
@MainActor
@Observable
final class PublishDraftStore {
    static let maxTitleCharacterCount = 30
    static let maxBodyCharacterCount = 1000

    var draft: PublishDraft
    var phase: PublishDraftPhase = .idle
    var successMessage: String?

    var titleText: String {
        get { draft.title }
        set { updateTitle(newValue) }
    }

    var bodyText: String {
        get { draft.bodyText }
        set { updateBodyText(newValue) }
    }

    init(context: PublishEntryContext) {
        self.draft = PublishDraft(context: context)
    }

    var canPrepareDraft: Bool {
        hasSelectedPet && hasContentPayload
    }

    var bodyCharacterCount: Int {
        draft.bodyText.count
    }

    func updateTitle(_ title: String) {
        draft.title = String(title.prefix(Self.maxTitleCharacterCount))
        phase = .idle
        successMessage = nil
    }

    func updateBodyText(_ bodyText: String) {
        draft.bodyText = String(bodyText.prefix(Self.maxBodyCharacterCount))
        phase = .idle
        successMessage = nil
    }

    func selectPet(id: String, name: String) {
        draft.selectedPetID = id
        draft.selectedPetName = name
        phase = .idle
        successMessage = nil
    }

    func selectEventType(_ eventType: PublishEventType) {
        draft.eventType = eventType
        phase = .idle
        successMessage = nil
    }

    func selectVisibility(_ visibility: PublishVisibility) {
        draft.visibility = visibility
        phase = .idle
        successMessage = nil
    }

    func selectLocation(city: String?, localEntityName: String?) {
        draft.city = city
        draft.localEntityName = localEntityName
        phase = .idle
        successMessage = nil
    }

    func addTopic(named topicName: String) {
        let normalizedName = topicName.normalizedPublishTopicName()
        guard !normalizedName.isEmpty,
              !draft.topicNames.contains(normalizedName)
        else {
            return
        }
        draft.topicNames.append(normalizedName)
        phase = .idle
        successMessage = nil
    }

    func removeTopic(named topicName: String) {
        draft.topicNames.removeAll { $0 == topicName }
        phase = .idle
        successMessage = nil
    }

    func updateTopics(_ topicNames: [String]) {
        let normalizedNames = topicNames.reduce(into: [String]()) { result, topicName in
            let normalizedName = topicName.normalizedPublishTopicName()
            guard !normalizedName.isEmpty,
                  !result.contains(normalizedName)
            else {
                return
            }
            result.append(normalizedName)
        }

        guard draft.topicNames != normalizedNames else {
            return
        }
        draft.topicNames = normalizedNames
        phase = .idle
        successMessage = nil
    }

    func updateMediaCount(_ mediaCount: Int) {
        draft.mediaCount = max(0, mediaCount)
        phase = .idle
        successMessage = nil
    }

    func prepareDraft() {
        guard canPrepareDraft else {
            return
        }
        phase = .prepared
        successMessage = "图文发布草稿已准备好"
    }

    private var hasSelectedPet: Bool {
        let petID = draft.selectedPetID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !petID.isEmpty
    }

    private var hasContentPayload: Bool {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyText = draft.bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty || !bodyText.isEmpty || draft.mediaCount > 0
    }
}

private extension String {
    func normalizedPublishTopicName() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "#" else {
            return trimmed
        }
        return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
