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
        do {
            for event in events {
                try await store.append(event)
            }
            if let remoteMirror {
                let result = await remoteMirror.appendBatch(events)
                await storageHealth.recordDroppedRemoteEvents(
                    count: result.droppedEventCount,
                    errorDescription: result.lastError
                )
            }
        } catch {
            await storageHealth.recordDroppedEvent(error)
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
