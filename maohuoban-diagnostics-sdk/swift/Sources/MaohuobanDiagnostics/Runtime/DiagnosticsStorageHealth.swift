import Foundation

// DiagnosticsStorageHealth 诊断存储健康状态
// 核心职责：
// - 记录事件落盘失败导致的丢弃数量
// - 为运行时快照提供 SDK 自身健康信号
actor DiagnosticsStorageHealth {
    private var droppedEventCount = 0
    private var lastStorageError = ""
    private var remoteDroppedEventCount = 0
    private var lastRemoteError = ""

    func recordDroppedEvent(_ error: Error) {
        droppedEventCount += 1
        lastStorageError = String(describing: error)
    }

    func recordDroppedRemoteEvents(count: Int, errorDescription: String) {
        guard count > 0 else {
            return
        }
        remoteDroppedEventCount += count
        lastRemoteError = errorDescription
    }

    func snapshot() -> DiagnosticsStorageHealthSnapshot {
        DiagnosticsStorageHealthSnapshot(
            droppedEventCount: droppedEventCount,
            lastStorageError: lastStorageError,
            remoteDroppedEventCount: remoteDroppedEventCount,
            lastRemoteError: lastRemoteError
        )
    }
}

// DiagnosticsStorageHealthSnapshot 存储健康快照
// 核心职责：
// - 承载运行时读取到的存储失败状态
// - 避免运行时快照直接暴露可变状态
struct DiagnosticsStorageHealthSnapshot {
    let droppedEventCount: Int
    let lastStorageError: String
    let remoteDroppedEventCount: Int
    let lastRemoteError: String
}
