import XCTest
@testable import maohuoban

// AIAssistantStreamingEngineAccumulationTests 流式文本累积测试
// 核心职责：
// - 锁定多次 flush 后输出文本保持递增
// - 防止流式渲染退化为单 chunk 替换
@MainActor
final class AIAssistantStreamingEngineAccumulationTests: XCTestCase {

    func testFlushAfterPreviousFlushPublishesAccumulatedText() {
        let engine = AIAssistantStreamingEngine()
        let messageID = UUID()
        var flushedTexts: [String] = []

        engine.onFlush = { _, text, _ in
            flushedTexts.append(text)
        }

        engine.begin(messageID: messageID)
        engine.appendDelta("毛球")
        engine.flush()

        engine.appendDelta("正在分析")
        engine.flush()

        XCTAssertEqual(flushedTexts, ["毛球", "毛球正在分析"])
    }
}
