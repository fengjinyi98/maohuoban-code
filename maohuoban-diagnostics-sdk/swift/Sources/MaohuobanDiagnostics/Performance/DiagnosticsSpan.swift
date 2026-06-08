import Foundation

// DiagnosticsSpan 性能 span
// 核心职责：
// - 记录一段业务或系统操作的耗时
// - 将耗时作为 performance 事件写入统一时间线
public final class DiagnosticsSpan: @unchecked Sendable {
    private let name: String
    private weak var runtime: DiagnosticsRuntime?
    private let startedAt: Date
    private let endLock = NSLock()
    private var hasEnded = false

    init(name: String, runtime: DiagnosticsRuntime) {
        self.name = name
        self.runtime = runtime
        startedAt = Date()
    }

    public func end(metadata: DiagnosticProperties = [:]) async {
        guard markEnded() else {
            return
        }
        let duration = Date().timeIntervalSince(startedAt)
        var event = DiagnosticEvent.performance(name)
            .metadata("duration_ms", "\(Int(duration * 1_000))")
        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        await runtime?.record(event)
    }

    private func markEnded() -> Bool {
        endLock.lock()
        defer {
            endLock.unlock()
        }
        guard !hasEnded else {
            return false
        }
        hasEnded = true
        return true
    }
}
