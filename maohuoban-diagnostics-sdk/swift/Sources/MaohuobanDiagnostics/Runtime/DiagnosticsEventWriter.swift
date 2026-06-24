import Foundation

// DiagnosticsEventWriter 运行时后台写入器
// 核心职责：
// - 将 record 热路径收敛为 bounded 内存入队
// - 在 flush/read/cleanup 边界批量落盘并镜像远端
actor DiagnosticsEventWriter {
    private let store: FileSegmentStore
    private let remoteMirror: DiagnosticsRemoteEventSink?
    private let storageHealth: DiagnosticsStorageHealth
    private let capacity: Int
    private let flushDelayNanoseconds: UInt64
    private var pending: [DiagnosticEvent] = []
    private var scheduledFlush = false

    init(
        store: FileSegmentStore,
        remoteMirror: DiagnosticsRemoteEventSink?,
        storageHealth: DiagnosticsStorageHealth,
        capacity: Int = 2_048,
        flushDelayNanoseconds: UInt64 = 500_000_000
    ) {
        self.store = store
        self.remoteMirror = remoteMirror
        self.storageHealth = storageHealth
        self.capacity = capacity
        self.flushDelayNanoseconds = flushDelayNanoseconds
    }

    func enqueue(_ event: DiagnosticEvent) async throws {
        guard pending.count < capacity else {
            throw DiagnosticsEventWriterError.queueFull
        }
        pending.append(event)
        scheduleFlushIfNeeded()
    }

    func flush() async throws {
        try await drainPending()
    }

    func readAll() async throws -> [DiagnosticEvent] {
        try await drainPending()
        return try await store.readAll()
    }

    private func scheduleFlushIfNeeded() {
        guard !scheduledFlush else {
            return
        }
        scheduledFlush = true
        Task {
            try? await Task.sleep(nanoseconds: flushDelayNanoseconds)
            await drainScheduled()
        }
    }

    private func drainScheduled() async {
        do {
            try await drainPending()
        } catch {
            await storageHealth.recordDroppedEvent(error)
        }
    }

    private func drainPending() async throws {
        guard !pending.isEmpty else {
            scheduledFlush = false
            return
        }
        let events = pending
        pending.removeAll()
        scheduledFlush = false
        let shouldDebugProfileAvatarUpload = events.contains {
            $0.metadata["issue_tag"] == "ProfileAvatarUpload"
        }
        let drainStartedAt = Date()
        var storeElapsedMs = 0
        var mirrorElapsedMs = 0
        var remoteSentEventCount = 0
        var remoteDroppedEventCount = 0
        do {
            let storeStartedAt = Date()
            for event in events {
                try await store.append(event)
            }
            storeElapsedMs = Int(Date().timeIntervalSince(storeStartedAt) * 1_000)
            if let remoteMirror {
                let mirrorStartedAt = Date()
                let result = await remoteMirror.appendBatch(events)
                mirrorElapsedMs = Int(Date().timeIntervalSince(mirrorStartedAt) * 1_000)
                remoteSentEventCount = result.sentEventCount
                remoteDroppedEventCount = result.droppedEventCount
                await storageHealth.recordDroppedRemoteEvents(
                    count: result.droppedEventCount,
                    errorDescription: result.lastError
                )
            }
            if shouldDebugProfileAvatarUpload {
                let totalElapsedMs = Int(Date().timeIntervalSince(drainStartedAt) * 1_000)
                print("[DEBUG:ProfileAvatarUpload] diagnostics writer drained count=\(events.count) store_ms=\(storeElapsedMs) mirror_ms=\(mirrorElapsedMs) total_ms=\(totalElapsedMs) remote_sent=\(remoteSentEventCount) remote_dropped=\(remoteDroppedEventCount)")
            }
        } catch {
            await storageHealth.recordDroppedEvent(error)
            if shouldDebugProfileAvatarUpload {
                let totalElapsedMs = Int(Date().timeIntervalSince(drainStartedAt) * 1_000)
                print("[DEBUG:ProfileAvatarUpload] diagnostics writer drain failed count=\(events.count) store_ms=\(storeElapsedMs) mirror_ms=\(mirrorElapsedMs) total_ms=\(totalElapsedMs) error=\(error)")
            }
            throw error
        }
    }
}

// DiagnosticsEventWriterError 后台写入错误
// 核心职责：
// - 暴露队列满等 SDK 自身健康信号
// - 让运行时快照可以汇总丢弃事件
enum DiagnosticsEventWriterError: Error {
    case queueFull
}
