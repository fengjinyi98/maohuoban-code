import XCTest
@testable import maohuoban

// AIAssistantDTOTests AI DTO 解码测试
// 核心职责：
// - 验证 SSE 事件 DTO 解码正确性
// - 验证历史会话和消息 DTO 解码正确性
@MainActor
final class AIAssistantDTOTests: XCTestCase {

    // MARK: - SSE 事件解码

    func testDecodeMessageStartedEvent() {
        let json = #"{"chat_session_id":"\#(UUID.zeroString)","message_id":"\#(UUID.zeroString)","title":"新对话"}"#
        let result = AIStreamEventDecoder.decode(event: "message_started", data: json)

        guard case let .messageStarted(chatSessionID, messageID, title) = result else {
            XCTFail("expected messageStarted")
            return
        }
        XCTAssertEqual(chatSessionID, UUID(uuidString: UUID.zeroString))
        XCTAssertEqual(messageID, UUID(uuidString: UUID.zeroString))
        XCTAssertEqual(title, "新对话")
    }

    func testDecodeDeltaEvent() {
        let json = #"{"text":"你好"}"#
        let result = AIStreamEventDecoder.decode(event: "delta", data: json)

        guard case let .delta(text) = result else {
            XCTFail("expected delta")
            return
        }
        XCTAssertEqual(text, "你好")
    }

    func testDecodeMessageCompletedEvent() {
        let json = """
        {"message_id":"\(UUID.zeroString)","final_text":"你好毛球","usage":{"input_tokens":10,"output_tokens":5,"total_tokens":15},"finish_reason":"stop","citations":[{"source_kind":"pet_event","source_id":"\(UUID.zeroString)","label":"疫苗记录"}],"verification":{"status":"passed"}}
        """
        let result = AIStreamEventDecoder.decode(event: "message_completed", data: json)

        guard case let .messageCompleted(_, finalText, chips) = result else {
            XCTFail("expected messageCompleted")
            return
        }
        XCTAssertEqual(finalText, "你好毛球")
        XCTAssertEqual(chips, ["疫苗记录"])
    }

    func testDecodeMessageCompletedWithoutCitations() {
        let json = """
        {"message_id":"\(UUID.zeroString)","final_text":"ok","usage":{"input_tokens":0,"output_tokens":0,"total_tokens":0},"finish_reason":"stop","citations":[],"verification":{"status":"passed"}}
        """
        let result = AIStreamEventDecoder.decode(event: "message_completed", data: json)

        guard case let .messageCompleted(_, _, chips) = result else {
            XCTFail("expected messageCompleted")
            return
        }
        XCTAssertTrue(chips.isEmpty)
    }

    func testDecodeErrorEvent() {
        let json = #"{"code":"ai.provider_not_configured","message":"AI 服务未配置","retryable":false,"safe_fallback_text":"暂时无法获取回答"}"#
        let result = AIStreamEventDecoder.decode(event: "error", data: json)

        guard case let .error(code, message, retryable, fallback) = result else {
            XCTFail("expected error")
            return
        }
        XCTAssertEqual(code, "ai.provider_not_configured")
        XCTAssertEqual(message, "AI 服务未配置")
        XCTAssertFalse(retryable)
        XCTAssertEqual(fallback, "暂时无法获取回答")
    }

    func testDecodeProposedActionEvent() {
        let json = """
        {"action":{"id":"\(UUID.zeroString)","action_kind":"diet_change_confirmation","target_pet_id":"\(UUID.zeroString)","confirm_text":"确认换粮","risk_level":"low","payload":{"food_item_id":"\(UUID.zeroString)","confirmed_fact_kind":"diet_change","source_question":"是否确认换粮？","derive_diet_change":true,"derive_feeding_correction":false}}}
        """
        let result = AIStreamEventDecoder.decode(event: "proposed_action", data: json)

        guard case let .proposedAction(action) = result else {
            XCTFail("expected proposedAction")
            return
        }
        XCTAssertEqual(action.actionKind, "diet_change_confirmation")
        XCTAssertEqual(action.confirmText, "确认换粮")
        XCTAssertEqual(action.riskLevel, "low")
        XCTAssertEqual(action.payload?.foodItemID, UUID(uuidString: UUID.zeroString))
        XCTAssertEqual(action.payload?.confirmedFactKind, "diet_change")
        XCTAssertEqual(action.payload?.sourceQuestion, "是否确认换粮？")
        XCTAssertTrue(action.payload?.deriveDietChange == true)
        XCTAssertTrue(action.payload?.deriveFeedingCorrection == false)
    }

    func testDecodeToolCallEvent() {
        let json = #"{"tool_name":"load_pet_identity_context","status":"allowed","citation_count":2}"#
        let result = AIStreamEventDecoder.decode(event: "tool_call", data: json)

        guard case let .toolCall(toolName, status, citationCount) = result else {
            XCTFail("expected toolCall")
            return
        }
        XCTAssertEqual(toolName, "load_pet_identity_context")
        XCTAssertEqual(status, "allowed")
        XCTAssertEqual(citationCount, 2)
    }

    func testDecodeAgentActivityEvent() {
        let json = #"{"display_text":"正在查看毛球近期饮食","status":"started"}"#
        let result = AIStreamEventDecoder.decode(event: "agent_activity", data: json)

        guard case let .agentActivity(displayText, status) = result else {
            XCTFail("expected agentActivity")
            return
        }
        XCTAssertEqual(displayText, "正在查看毛球近期饮食")
        XCTAssertEqual(status, "started")
    }

    func testDecodeConfirmationTaskEvent() {
        let json = #"{"confirmation_task_id":"\#(UUID.zeroString)","question_text":"是否确认把毛球的主粮改为鸡肉配方？"}"#
        let result = AIStreamEventDecoder.decode(event: "confirmation_task", data: json)

        guard case let .confirmationTask(taskID, questionText) = result else {
            XCTFail("expected confirmationTask")
            return
        }
        XCTAssertEqual(taskID, UUID(uuidString: UUID.zeroString))
        XCTAssertEqual(questionText, "是否确认把毛球的主粮改为鸡肉配方？")
    }

    func testDecodeUnknownEventReturnsNil() {
        let result = AIStreamEventDecoder.decode(event: "unknown_event", data: "{}")
        XCTAssertNil(result)
    }

    func testDecodeInvalidJSONReturnsNil() {
        let result = AIStreamEventDecoder.decode(event: "delta", data: "not json")
        XCTAssertNil(result)
    }

    func testSSEParserFlushesEventWhenNextEventStartsWithoutBlankLine() {
        var parser = AIStreamEventParser()
        let startedData = #"{"chat_session_id":"\#(UUID.zeroString)","message_id":"\#(UUID.zeroString)","title":"新对话"}"#
        let errorData = #"{"code":"ai.provider_not_configured","message":"AI 服务未配置","retryable":false,"safe_fallback_text":"暂时无法获取回答"}"#

        var parsed: [AIStreamParsedEvent] = []
        parsed += parser.consumeLine("event: message_started")
        parsed += parser.consumeLine("data: \(startedData)")
        parsed += parser.consumeLine("event: error")
        parsed += parser.consumeLine("data: \(errorData)")
        parsed += parser.finish()

        XCTAssertEqual(parsed.map(\.eventName), ["message_started", "error"])
        guard case .messageStarted = parsed[0].event else {
            XCTFail("expected messageStarted")
            return
        }
        guard case let .error(code, _, retryable, fallback) = parsed[1].event else {
            XCTFail("expected error")
            return
        }
        XCTAssertEqual(code, "ai.provider_not_configured")
        XCTAssertFalse(retryable)
        XCTAssertEqual(fallback, "暂时无法获取回答")
    }

    func testSSEParserFlushesPendingEventAtEndOfStream() {
        var parser = AIStreamEventParser()
        let errorData = #"{"code":"ai.provider_not_configured","message":"AI 服务未配置","retryable":false,"safe_fallback_text":"暂时无法获取回答"}"#

        XCTAssertTrue(parser.consumeLine("event: error").isEmpty)
        XCTAssertTrue(parser.consumeLine("data: \(errorData)").isEmpty)

        let parsed = parser.finish()

        XCTAssertEqual(parsed.map(\.eventName), ["error"])
        guard case let .error(code, _, _, fallback) = parsed[0].event else {
            XCTFail("expected error")
            return
        }
        XCTAssertEqual(code, "ai.provider_not_configured")
        XCTAssertEqual(fallback, "暂时无法获取回答")
    }

    // MARK: - 历史会话 DTO 解码

    func testDecodeChatSessionList() throws {
        let json = """
        [{"id":"\(UUID.zeroString)","title":"疫苗咨询","is_pinned":true,"subtitle":"今天","pet_display_snapshot":{"pet_id":"\(UUID.zeroString)","pet_name":"毛球","pet_avatar_url":null,"pet_species":"cat","profile_number":"P001"},"last_message_preview":"下次疫苗在八月","last_message_at":"2026-06-27T10:00:00Z"}]
        """
        let data = json.data(using: .utf8)!
        let sessions = try JSONDecoder().decode([AIChatSessionDTO].self, from: data)

        XCTAssertEqual(sessions.count, 1)
        let session = sessions[0]
        XCTAssertEqual(session.title, "疫苗咨询")
        XCTAssertTrue(session.isPinned)
        XCTAssertEqual(session.subtitle, "今天")
        XCTAssertEqual(session.lastMessagePreview, "下次疫苗在八月")
        XCTAssertEqual(session.petDisplaySnapshot?.petName, "毛球")
        XCTAssertNil(session.petDisplaySnapshot?.petAvatarURL)
        XCTAssertEqual(session.petDisplaySnapshot?.petSpecies, "cat")
    }

    func testHistoryMapsPetDisplaySnapshotToRowModel() throws {
        let json = """
        [{"id":"\(UUID.zeroString)","title":"饮食咨询","is_pinned":false,"subtitle":"刚刚","pet_display_snapshot":{"pet_id":"\(UUID.zeroString)","pet_name":"毛球","pet_avatar_url":"https://cdn.example.com/pets/mao.png","pet_species":"cat","profile_number":"P001"},"last_message_preview":"已读取饮食记录","last_message_at":"2026-06-27T10:00:00Z"}]
        """
        let data = json.data(using: .utf8)!
        let sessions = try JSONDecoder().decode([AIChatSessionDTO].self, from: data)

        let history = AIAssistantConversationHistory(from: sessions[0])

        XCTAssertEqual(history.petName, "毛球")
        XCTAssertEqual(history.petAvatarURL, "https://cdn.example.com/pets/mao.png")
        XCTAssertEqual(history.petSpecies, .cat)
        XCTAssertEqual(history.messages.last?.text, "已读取饮食记录")
    }

    func testDecodeChatSessionWithoutSnapshot() throws {
        let json = """
        [{"id":"\(UUID.zeroString)","title":"测试","subtitle":"昨天","pet_display_snapshot":null,"last_message_preview":"","last_message_at":"2026-06-26T10:00:00Z"}]
        """
        let data = json.data(using: .utf8)!
        let sessions = try JSONDecoder().decode([AIChatSessionDTO].self, from: data)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertNil(sessions[0].petDisplaySnapshot)
    }

    func testDecodeMessageList() throws {
        let json = """
        [{"id":"\(UUID.zeroString)","role":"user","content":"毛球拉肚子了","created_at":"2026-06-27T10:00:00Z"},{"id":"\(UUID.zeroString)","role":"assistant","content":"需要观察精神状态","created_at":"2026-06-27T10:00:05Z"}]
        """
        let data = json.data(using: .utf8)!
        let messages = try JSONDecoder().decode([AIMessageDTO].self, from: data)

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, "user")
        XCTAssertEqual(messages[0].content, "毛球拉肚子了")
        XCTAssertEqual(messages[1].role, "assistant")
        XCTAssertEqual(messages[1].content, "需要观察精神状态")
    }
}

// MARK: - 测试辅助

private extension UUID {
    static let zeroString = "00000000-0000-0000-0000-000000000000"
}
