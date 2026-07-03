import XCTest
@testable import maohuoban

// AIAssistantHistoryDTOTests AI 历史 DTO 解码测试
// 核心职责：
// - 验证历史会话列表 DTO 解码正确性
// - 验证历史消息 DTO 内容块映射正确性
@MainActor
final class AIAssistantHistoryDTOTests: XCTestCase {
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

    func testDecodeMessageListWithContentBlocks() throws {
        let json = """
        [{"id":"\(UUID.zeroString)","role":"assistant","content":"这是糯米的宠物信息","content_blocks":[{"id":"heading-1","type":"section_heading","text":"这是糯米的宠物信息"}],"created_at":"2026-06-27T10:00:05Z"}]
        """
        let data = json.data(using: .utf8)!
        let messages = try JSONDecoder().decode([AIMessageDTO].self, from: data)

        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].contentBlocks.count, 1)
        guard case let .sectionHeading(block) = messages[0].contentBlocks[0] else {
            XCTFail("expected section heading")
            return
        }
        XCTAssertEqual(block.text, "这是糯米的宠物信息")
    }
}

private extension UUID {
    static let zeroString = "00000000-0000-0000-0000-000000000000"
}
