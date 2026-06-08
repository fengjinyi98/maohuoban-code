import Foundation

// DiagnosticsContext 诊断上下文
// 核心职责：
// - 保存全局 session、trace 和默认 metadata
// - 在统一记录管线中为后续事件补齐上下文
actor DiagnosticsContext {
    private var sessionID: String?
    private var traceID: String?
    private var metadata: [String: String] = [:]

    func setSessionID(_ sessionID: String) {
        self.sessionID = sessionID
    }

    func clearSessionID() {
        sessionID = nil
    }

    func setTraceID(_ traceID: String) {
        self.traceID = traceID
    }

    func withTraceID<T: Sendable>(
        _ traceID: String,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let previous = self.traceID
        self.traceID = traceID
        defer {
            self.traceID = previous
        }
        return try await operation()
    }

    func clearTraceID() {
        traceID = nil
    }

    func setMetadata(_ key: String, _ value: String) {
        metadata[key] = value
    }

    func removeMetadata(_ key: String) {
        metadata.removeValue(forKey: key)
    }

    func clearMetadata() {
        metadata.removeAll()
    }

    func apply(to event: DiagnosticEvent) -> DiagnosticEvent {
        let eventMetadata = metadata.merging(event.metadata) { _, eventValue in eventValue }
        return DiagnosticEvent(
            id: event.id,
            timestamp: event.timestamp,
            kind: event.kind,
            severity: event.severity,
            message: event.message,
            traceID: event.traceID ?? traceID,
            sessionID: event.sessionID ?? sessionID,
            metadata: eventMetadata
        )
    }
}
