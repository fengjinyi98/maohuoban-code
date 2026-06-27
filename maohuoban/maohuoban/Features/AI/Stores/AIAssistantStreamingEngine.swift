import Foundation

// AIAssistantStreamingEngine 流式输出引擎
// 核心职责：
// - 管理 delta 合并队列和延迟 flush
// - 通过 onFlush 回调通知 Store 更新单条消息
// - 支持增量型和累积快照型文本合并
@MainActor
final class AIAssistantStreamingEngine {

    /// flush 回调：(消息 ID, 合并后文本, 是否仍在流式)
    var onFlush: ((UUID, String, Bool) -> Void)?

    private(set) var activeMessageID: UUID?
    private var accumulatedText: String = ""
    private var lastFlushedText: String = ""
    private var pendingDelta: String = ""
    private var flushTask: Task<Void, Never>?

    var isStreaming: Bool { activeMessageID != nil }

    var pendingDeltaText: String { pendingDelta }

    /// 开始流式输出，创建占位消息
    func begin(messageID: UUID) {
        debugLog("begin_before nextMessageID=\(String(messageID.uuidString.prefix(8)))")
        cancel()
        activeMessageID = messageID
        accumulatedText = ""
        lastFlushedText = ""
        pendingDelta = ""
        debugLog("begin_after")
    }

    /// 追加 delta 文本到合并队列
    func appendDelta(_ delta: String) {
        guard activeMessageID != nil, !delta.isEmpty else { return }

        if delta.hasPrefix(accumulatedText) {
            accumulatedText = delta
        } else {
            accumulatedText += delta
        }

        pendingDelta = accumulatedText.hasPrefix(lastFlushedText)
            ? String(accumulatedText.dropFirst(lastFlushedText.count))
            : accumulatedText
        debugLog("append_delta deltaLen=\(delta.count)")
    }

    /// 立即 flush 当前待刷入的 delta
    func flush() {
        guard let messageID = activeMessageID else { return }
        guard accumulatedText != lastFlushedText else { return }
        debugLog("flush_before")

        let textToFlush = accumulatedText
        lastFlushedText = accumulatedText
        pendingDelta = ""

        onFlush?(messageID, textToFlush, true)
        debugLog("flush_after")
    }

    /// 完成流式输出，用最终文本替换并关闭流式状态
    func complete(finalText: String) {
        guard let messageID = activeMessageID else { return }
        debugLog("complete_before finalLen=\(finalText.count)")

        cancelFlushTask()
        accumulatedText = finalText
        lastFlushedText = finalText
        pendingDelta = ""
        activeMessageID = nil

        onFlush?(messageID, finalText, false)
        debugLog("complete_after")
    }

    /// 取消流式输出，清空所有待处理状态
    func cancel() {
        debugLog("cancel_before")
        cancelFlushTask()
        accumulatedText = ""
        lastFlushedText = ""
        pendingDelta = ""
        activeMessageID = nil
        debugLog("cancel_after")
    }

    private func cancelFlushTask() {
        flushTask?.cancel()
        flushTask = nil
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        let activePrefix = activeMessageID.map { String($0.uuidString.prefix(8)) } ?? "nil"
        print(
            "[DEBUG:AISendLock] streaming_engine \(message) activeMessageID=\(activePrefix) accumulatedLen=\(accumulatedText.count) lastFlushedLen=\(lastFlushedText.count) pendingLen=\(pendingDelta.count)"
        )
        #endif
    }
}
