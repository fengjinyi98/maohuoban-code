import XCTest
@testable import maohuoban

// HomeRealtimeEventParserTests 首页实时事件解析测试
// 核心职责：
// - 验证首页 SSE 行解析能够识别轻提醒投影事件
// - 固化后端事件字段到前端模型的解码合同
final class HomeRealtimeEventParserTests: XCTestCase {
    @MainActor
    func testParserDecodesAttentionHintProjectedEvent() throws {
        var parser = HomeRealtimeEventParser()
        let data = """
        {"event":"attention_hint_projected","pet_id":"pet-1","hint_id":"hint-1","kind":"attention_hint_projected","source_ref_type":"agent_proactive_followup","source_ref_id":"followup-1","occurred_at":"2026-07-06T09:00:52Z"}
        """

        XCTAssertTrue(parser.consumeLine("event: attention_hint_projected").isEmpty)
        XCTAssertTrue(parser.consumeLine("data: \(data)").isEmpty)

        let parsed = parser.finish()

        XCTAssertEqual(parsed.map(\.eventName), ["attention_hint_projected"])
        let event = try XCTUnwrap(parsed.first?.event)
        XCTAssertEqual(event.event, "attention_hint_projected")
        XCTAssertEqual(event.petID, "pet-1")
        XCTAssertEqual(event.hintID, "hint-1")
        XCTAssertEqual(event.sourceRefType, "agent_proactive_followup")
        XCTAssertEqual(event.sourceRefID, "followup-1")
    }
}
