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
        cancel()
        activeMessageID = messageID
        accumulatedText = ""
        lastFlushedText = ""
        pendingDelta = ""
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
    }

    /// 立即 flush 当前待刷入的 delta
    func flush() {
        guard let messageID = activeMessageID else { return }
        guard accumulatedText != lastFlushedText else { return }

        let textToFlush = accumulatedText
        lastFlushedText = accumulatedText
        pendingDelta = ""

        onFlush?(messageID, textToFlush, true)
    }

    /// 完成流式输出，用最终文本替换并关闭流式状态
    func complete(finalText: String) {
        guard let messageID = activeMessageID else { return }

        cancelFlushTask()
        accumulatedText = finalText
        lastFlushedText = finalText
        pendingDelta = ""
        activeMessageID = nil

        onFlush?(messageID, finalText, false)
    }

    /// 取消流式输出，清空所有待处理状态
    func cancel() {
        cancelFlushTask()
        accumulatedText = ""
        lastFlushedText = ""
        pendingDelta = ""
        activeMessageID = nil
    }

    private func cancelFlushTask() {
        flushTask?.cancel()
        flushTask = nil
    }
}
