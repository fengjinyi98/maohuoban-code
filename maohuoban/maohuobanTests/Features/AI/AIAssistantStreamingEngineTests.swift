import XCTest
@testable import maohuoban

// AIAssistantStreamingEngineTests 流式引擎单测
// 核心职责：
// - 锁定 delta 合并、延迟 flush、生命周期流转和取消行为
// - 确保流式 patch 不重建整条消息数组
@MainActor
final class AIAssistantStreamingEngineTests: XCTestCase {

    // MARK: - 生命周期

    func testBeginCreatesStreamingPlaceholder() {
        let engine = AIAssistantStreamingEngine()
        let messageID = UUID()

        engine.begin(messageID: messageID)

        XCTAssertTrue(engine.isStreaming)
        XCTAssertEqual(engine.activeMessageID, messageID)
    }

    func testCompleteSetsIsStreamingFalse() {
        let engine = AIAssistantStreamingEngine()
        let messageID = UUID()
        engine.begin(messageID: messageID)
        engine.appendDelta("部分文本")

        engine.complete(finalText: "最终完整文本")

        XCTAssertFalse(engine.isStreaming)
        XCTAssertNil(engine.activeMessageID)
    }

    func testCancelClearsPendingDeltas() {
        let engine = AIAssistantStreamingEngine()
        let messageID = UUID()
        engine.begin(messageID: messageID)
        engine.appendDelta("待刷入")
        engine.appendDelta("更多")

        engine.cancel()

        XCTAssertFalse(engine.isStreaming)
        XCTAssertNil(engine.activeMessageID)
        XCTAssertTrue(engine.pendingDeltaText.isEmpty)
    }

    // MARK: - Delta 合并

    func testDeltaCoalescingAppliesOrderedDeltasOnFlush() {
        let engine = AIAssistantStreamingEngine()
        let messageID = UUID()
        var flushCount = 0
        var flushedText = ""

        engine.onFlush = { id, text, isStreaming in
            flushCount += 1
            flushedText = text
        }

        engine.begin(messageID: messageID)
        engine.appendDelta("Hello")
        engine.appendDelta(" world")

        // flush 前不触发回调
        XCTAssertEqual(flushCount, 0)

        engine.flush()

        XCTAssertEqual(flushCount, 1)
        XCTAssertEqual(flushedText, "Hello world")
    }

    func testDeltaCoalescingMergesCumulativeSnapshotsBeforeFlush() {
        let engine = AIAssistantStreamingEngine()
        let messageID = UUID()
        var flushedText = ""

        engine.onFlush = { _, text, _ in
            flushedText = text
        }

        engine.begin(messageID: messageID)
        // 模拟累积快照型 delta（后一个包含前一个）
        engine.appendDelta("Yes")
        engine.appendDelta("Yes, the")
        engine.appendDelta("Yes, the imagegen skill")

        engine.flush()

        // 最终应取最后一个完整快照
        XCTAssertEqual(flushedText, "Yes, the imagegen skill")
    }

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

    func testFlushUpdatesStreamingRevision() {
        let engine = AIAssistantStreamingEngine()
        let messageID = UUID()
        var revision = 0

        engine.onFlush = { _, _, _ in
            revision += 1
        }

        engine.begin(messageID: messageID)
        engine.appendDelta("First")
        engine.flush()

        let firstRevision = revision

        engine.appendDelta(" chunk")
        engine.flush()

        XCTAssertGreaterThan(revision, firstRevision)
    }

    // MARK: - 完成时回调

    func testCompleteInvokesCallbackWithFinalText() {
        let engine = AIAssistantStreamingEngine()
        let messageID = UUID()
        var lastFlushedText = ""
        var lastFlushedIsStreaming = true

        engine.onFlush = { _, text, isStreaming in
            lastFlushedText = text
            lastFlushedIsStreaming = isStreaming
        }

        engine.begin(messageID: messageID)
        engine.appendDelta("临时内容")
        engine.flush()

        engine.complete(finalText: "最终替换文本")

        // complete 应该触发一次 flush，携带最终文本和 isStreaming=false
        XCTAssertEqual(lastFlushedText, "最终替换文本")
        XCTAssertFalse(lastFlushedIsStreaming)
    }

    // MARK: - 无活跃流时安全忽略

    func testAppendDeltaWithoutBeginIsIgnored() {
        let engine = AIAssistantStreamingEngine()
        var flushCount = 0

        engine.onFlush = { _, _, _ in
            flushCount += 1
        }

        engine.appendDelta("不应该被处理")
        engine.flush()

        XCTAssertEqual(flushCount, 0)
        XCTAssertFalse(engine.isStreaming)
    }

    func testFlushWithoutActiveStreamIsNoop() {
        let engine = AIAssistantStreamingEngine()
        var flushCount = 0

        engine.onFlush = { _, _, _ in
            flushCount += 1
        }

        engine.flush()

        XCTAssertEqual(flushCount, 0)
    }
}
