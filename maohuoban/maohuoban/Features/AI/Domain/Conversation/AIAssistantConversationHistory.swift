import Foundation

// AIAssistantConversationHistory AI 对话历史会话
// 核心职责：
// - 为对话记录页面提供会话展示数据
// - 携带选中后回填聊天页的消息列表
struct AIAssistantConversationHistory: Identifiable, Hashable {
    let id: String
    let title: String
    let isPinned: Bool
    let subtitle: String
    let messages: [AIAssistantMessage]
    let petAvatarURL: String?
    let petName: String
    let petSpecies: AIAssistantPetSpecies

    init(
        id: String,
        title: String,
        subtitle: String,
        messages: [AIAssistantMessage],
        petAvatarURL: String?,
        petName: String,
        petSpecies: AIAssistantPetSpecies,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.isPinned = isPinned
        self.subtitle = subtitle
        self.messages = messages
        self.petAvatarURL = petAvatarURL
        self.petName = petName
        self.petSpecies = petSpecies
    }
}

// MARK: - DTO 映射

extension AIAssistantConversationHistory {
    init(from dto: AIChatSessionDTO) {
        let snapshot = dto.petDisplaySnapshot
        self.init(
            id: dto.id.uuidString,
            title: dto.title,
            subtitle: dto.subtitle,
            messages: [
                AIAssistantMessage(
                    role: .assistant,
                    text: dto.lastMessagePreview.isEmpty ? "暂无消息" : dto.lastMessagePreview
                )
            ],
            petAvatarURL: snapshot?.petAvatarURL,
            petName: snapshot?.petName ?? "宠物",
            petSpecies: AIAssistantPetSpecies.from(dto.petDisplaySnapshot?.petSpecies),
            isPinned: dto.isPinned
        )
    }

    func updating(title: String? = nil, isPinned: Bool? = nil) -> AIAssistantConversationHistory {
        AIAssistantConversationHistory(
            id: id,
            title: title ?? self.title,
            subtitle: subtitle,
            messages: messages,
            petAvatarURL: petAvatarURL,
            petName: petName,
            petSpecies: petSpecies,
            isPinned: isPinned ?? self.isPinned
        )
    }
}

extension AIAssistantPetSpecies {
    static func from(_ species: String?) -> AIAssistantPetSpecies {
        guard let species else { return .other }
        switch species.lowercased() {
        case "dog": return .dog
        case "cat": return .cat
        default: return .other
        }
    }
}
