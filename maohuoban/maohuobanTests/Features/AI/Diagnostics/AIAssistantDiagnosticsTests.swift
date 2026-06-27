import XCTest
import MaohuobanDiagnostics
@testable import maohuoban

// AIAssistantDiagnosticsTests AI 助手诊断事件测试
// 核心职责：
// - 验证 AI 聊天链路观测事件的名称和脱敏元数据
// - 防止流式内容和历史详情被写入诊断包
@MainActor
final class AIAssistantDiagnosticsTests: XCTestCase {
    override func tearDown() {
        Task {
            await Diagnostics.uninstall()
        }
        super.tearDown()
    }

    func testStreamEventReceivedRecordsSafeSSEMetadata() async throws {
        let diagnostics = try await installDiagnostics()
        let sessionID = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        let messageID = UUID(uuidString: "87654321-4321-4321-4321-CBA987654321")!

        await AIAssistantDiagnostics.recordStreamEventReceived(
            eventName: "message_started",
            event: .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "原始标题不应进入诊断")
        )
        await AIAssistantDiagnostics.recordStreamEventReceived(
            eventName: "delta",
            event: .delta(text: "这是一段不应进入诊断的回复正文")
        )

        let events = try await diagnostics.readEvents()
        let started = try XCTUnwrap(events.first { $0.message == "ai.chat.stream.event.received" })
        XCTAssertEqual(started.kind, .analytics)
        XCTAssertEqual(started.metadata["event_name"], "message_started")
        XCTAssertEqual(started.metadata["chat_session_id_prefix"], "12345678")
        XCTAssertEqual(started.metadata["message_id_prefix"], "87654321")
        XCTAssertNil(started.metadata["title"])

        let delta = try XCTUnwrap(events.last { $0.message == "ai.chat.stream.event.received" })
        XCTAssertEqual(delta.metadata["event_name"], "delta")
        XCTAssertEqual(delta.metadata["delta_length_bucket"], "1_32")
        XCTAssertNil(delta.metadata["text"])
    }

    func testHistoryLoadedRecordsCountsAndSelectionWithoutContent() async throws {
        let diagnostics = try await installDiagnostics()

        await AIAssistantDiagnostics.recordHistorySessionsLoaded(
            sessionCount: 3,
            pinnedCount: 1,
            petSnapshotCount: 2
        )
        await AIAssistantDiagnostics.recordHistoryMessagesLoaded(
            sessionID: "ABCDEF12-3456-7890-ABCD-EF1234567890",
            messageCount: 4
        )

        let events = try await diagnostics.readEvents()
        let sessions = try XCTUnwrap(events.first { $0.message == "ai.history.sessions.loaded" })
        XCTAssertEqual(sessions.metadata["session_count"], 3)
        XCTAssertEqual(sessions.metadata["pinned_count"], 1)
        XCTAssertEqual(sessions.metadata["pet_snapshot_count"], 2)

        let messages = try XCTUnwrap(events.first { $0.message == "ai.history.messages.loaded" })
        XCTAssertEqual(messages.metadata["chat_session_id_prefix"], "ABCDEF12")
        XCTAssertEqual(messages.metadata["message_count"], 4)
        XCTAssertNil(messages.metadata["message_text"])
    }

    private func installDiagnostics() async throws -> DiagnosticsRuntime {
        await Diagnostics.uninstall()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("maohuoban-ai-diagnostics-tests-\(UUID().uuidString)", isDirectory: true)
        return try await Diagnostics.install(
            DiagnosticsConfiguration(
                serviceName: "maohuoban-ios-tests",
                environment: "test",
                storageDirectory: root
            )
        )
    }
}
