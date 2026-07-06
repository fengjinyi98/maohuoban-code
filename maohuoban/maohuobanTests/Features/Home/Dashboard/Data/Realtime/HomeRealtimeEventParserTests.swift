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

    @MainActor
    func testParserDecodesTimelineChangedEventWithoutHintID() throws {
        var parser = HomeRealtimeEventParser()
        let data = """
        {"event":"timeline_changed","pet_id":"pet-1","kind":"timeline_changed","source_ref_type":"pet_event","source_ref_id":"event-1","occurred_at":"2026-07-06T17:28:11Z"}
        """

        XCTAssertTrue(parser.consumeLine("event: timeline_changed").isEmpty)
        XCTAssertTrue(parser.consumeLine("data: \(data)").isEmpty)

        let parsed = parser.finish()

        XCTAssertEqual(parsed.map(\.eventName), ["timeline_changed"])
        let event = try XCTUnwrap(parsed.first?.event)
        XCTAssertEqual(event.event, "timeline_changed")
        XCTAssertEqual(event.petID, "pet-1")
        XCTAssertNil(event.hintID)
        XCTAssertEqual(event.sourceRefType, "pet_event")
        XCTAssertEqual(event.sourceRefID, "event-1")
    }
}
