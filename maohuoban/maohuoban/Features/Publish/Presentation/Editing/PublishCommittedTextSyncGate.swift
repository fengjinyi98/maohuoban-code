import Foundation

// PublishCommittedTextSyncGate 发布正文输入同步门闩
// 核心职责：
// - 合并同一轮输入里的多次 committed 文本回调
// - 避免旧快照覆盖更晚到达的最终正文
struct PublishCommittedTextSyncGate {
    private(set) var latestScheduledSnapshot: String?

    mutating func recordCommittedSnapshot(_ snapshot: String) -> String {
        latestScheduledSnapshot = snapshot
        return snapshot
    }

    func shouldApply(
        scheduledSnapshot: String,
        currentText: String,
        isMarked: Bool
    ) -> Bool {
        guard isMarked == false else { return false }
        guard latestScheduledSnapshot == scheduledSnapshot else { return false }
        return currentText == scheduledSnapshot
    }

    mutating func finish(scheduledSnapshot: String) {
        guard latestScheduledSnapshot == scheduledSnapshot else { return }
        latestScheduledSnapshot = nil
    }
}
