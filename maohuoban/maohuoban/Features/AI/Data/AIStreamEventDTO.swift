import Foundation

// AIStreamEventDTO AI 流式事件 DTO
// 核心职责：
// - 表达后端 SSE 事件的稳定前端模型
// - 屏蔽后端枚举序列化差异，iOS 只消费自家事件协议
enum AIStreamEventDTO {
    case messageStarted(chatSessionID: UUID, messageID: UUID, title: String)
    case delta(text: String)
    case messageCompleted(messageID: UUID, finalText: String, referenceChips: [String])
    case proposedAction(action: AIProposedActionDTO)
    case error(code: String, message: String, retryable: Bool, safeFallbackText: String?)
}

// AIProposedActionDTO 建议动作 DTO
// 核心职责：
// - 解码后端 proposed_action SSE 事件中的动作载荷
// - 映射到前端 AIAssistantProposedAction
struct AIProposedActionDTO: Decodable {
    let id: UUID
    let actionKind: String
    let targetPetID: UUID
    let confirmText: String
    let riskLevel: String
    let payload: AIProposedActionPayloadDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case actionKind = "action_kind"
        case targetPetID = "target_pet_id"
        case confirmText = "confirm_text"
        case riskLevel = "risk_level"
        case payload
    }
}

// AIProposedActionPayloadDTO 建议动作确认 payload DTO
// 核心职责：
// - 解码后端 proposed action 中的确认接口字段
// - 将 snake_case 字段转换为前端稳定模型
struct AIProposedActionPayloadDTO: Decodable {
    let foodItemID: UUID?
    let confirmedFactKind: String?
    let sourceQuestion: String?
    let deriveDietChange: Bool
    let deriveFeedingCorrection: Bool

    enum CodingKeys: String, CodingKey {
        case foodItemID = "food_item_id"
        case confirmedFactKind = "confirmed_fact_kind"
        case sourceQuestion = "source_question"
        case deriveDietChange = "derive_diet_change"
        case deriveFeedingCorrection = "derive_feeding_correction"
    }

    init(
        foodItemID: UUID?,
        confirmedFactKind: String?,
        sourceQuestion: String?,
        deriveDietChange: Bool,
        deriveFeedingCorrection: Bool
    ) {
        self.foodItemID = foodItemID
        self.confirmedFactKind = confirmedFactKind
        self.sourceQuestion = sourceQuestion
        self.deriveDietChange = deriveDietChange
        self.deriveFeedingCorrection = deriveFeedingCorrection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        foodItemID = try container.decodeIfPresent(UUID.self, forKey: .foodItemID)
        confirmedFactKind = try container.decodeIfPresent(String.self, forKey: .confirmedFactKind)
        sourceQuestion = try container.decodeIfPresent(String.self, forKey: .sourceQuestion)
        deriveDietChange = try container.decodeIfPresent(Bool.self, forKey: .deriveDietChange) ?? false
        deriveFeedingCorrection = try container.decodeIfPresent(Bool.self, forKey: .deriveFeedingCorrection) ?? false
    }
}

// AIStreamEventDecoder SSE 事件解码器
// 核心职责：
// - 根据 SSE event 名称解码 JSON data 为 AIStreamEventDTO
// - 忽略前端不关注的事件类型
enum AIStreamEventDecoder {

    /// decode 将 SSE event 名称和 JSON 字符串解码为 AIStreamEventDTO
    static func decode(event: String, data: String) -> AIStreamEventDTO? {
        guard let jsonData = data.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()

        switch event {
        case "message_started":
            guard let payload = try? decoder.decode(MessageStartedPayload.self, from: jsonData) else { return nil }
            return .messageStarted(chatSessionID: payload.chatSessionID, messageID: payload.messageID, title: payload.title)

        case "delta":
            guard let payload = try? decoder.decode(DeltaPayload.self, from: jsonData) else { return nil }
            return .delta(text: payload.text)

        case "message_completed":
            guard let payload = try? decoder.decode(MessageCompletedPayload.self, from: jsonData) else { return nil }
            let chips = payload.citations?.map(\.label) ?? []
            return .messageCompleted(messageID: payload.messageID, finalText: payload.finalText, referenceChips: chips)

        case "proposed_action":
            guard let payload = try? decoder.decode(ProposedActionPayload.self, from: jsonData) else { return nil }
            return .proposedAction(action: payload.action)

        case "error":
            guard let payload = try? decoder.decode(ErrorPayload.self, from: jsonData) else { return nil }
            return .error(
                code: payload.code,
                message: payload.message,
                retryable: payload.retryable,
                safeFallbackText: payload.safeFallbackText
            )

        default:
            return nil
        }
    }
}

// MARK: - SSE Payload 私有解码结构

private struct MessageStartedPayload: Decodable {
    let chatSessionID: UUID
    let messageID: UUID
    let title: String

    enum CodingKeys: String, CodingKey {
        case chatSessionID = "chat_session_id"
        case messageID = "message_id"
        case title
    }
}

private struct DeltaPayload: Decodable {
    let text: String
}

private struct MessageCompletedPayload: Decodable {
    let messageID: UUID
    let finalText: String
    let citations: [CitationLabelDTO]?

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case finalText = "final_text"
        case citations
    }
}

private struct CitationLabelDTO: Decodable {
    let label: String
}

private struct ProposedActionPayload: Decodable {
    let action: AIProposedActionDTO
}

private struct ErrorPayload: Decodable {
    let code: String
    let message: String
    let retryable: Bool
    let safeFallbackText: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case retryable
        case safeFallbackText = "safe_fallback_text"
    }
}

// MARK: - 建议动作 DTO 映射

extension AIAssistantProposedAction {
    init(from dto: AIProposedActionDTO) {
        self.init(
            id: dto.id.uuidString,
            actionKind: dto.actionKind,
            targetPetID: dto.targetPetID.uuidString,
            title: AIAssistantProposedAction.titleText(for: dto.actionKind),
            subtitle: dto.confirmText,
            confirmTitle: dto.confirmText,
            cancelTitle: "暂不确认",
            systemImage: AIAssistantProposedAction.systemImage(for: dto.actionKind),
            payload: dto.payload.map { payload in
                AIAssistantProposedActionPayload(
                    foodItemID: payload.foodItemID?.uuidString,
                    confirmedFactKind: payload.confirmedFactKind,
                    sourceQuestion: payload.sourceQuestion,
                    deriveDietChange: payload.deriveDietChange,
                    deriveFeedingCorrection: payload.deriveFeedingCorrection
                )
            }
        )
    }

    private static func titleText(for actionKind: String) -> String {
        switch actionKind {
        case "diet_change_confirmation": "确认换粮"
        case "feeding_correction": "修正喂食"
        case "symptom_followup": "记录症状"
        case "reminder_creation": "添加提醒"
        case "risk_context_confirmation": "确认风险"
        default: "确认动作"
        }
    }

    private static func systemImage(for actionKind: String) -> String {
        switch actionKind {
        case "diet_change_confirmation": "fork.knife"
        case "feeding_correction": "pencil.line"
        case "symptom_followup": "waveform.path.ecg"
        case "reminder_creation": "calendar.badge.plus"
        case "risk_context_confirmation": "exclamationmark.shield"
        default: "checkmark.circle"
        }
    }
}
