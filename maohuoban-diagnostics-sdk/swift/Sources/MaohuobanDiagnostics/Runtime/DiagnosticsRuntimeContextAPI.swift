// DiagnosticsRuntimeContextAPI 运行时上下文 API
// 核心职责：
// - 管理 session、trace 和默认 metadata
// - 为后续事件补齐稳定上下文
extension DiagnosticsRuntime {
    public func setSessionID(_ sessionID: String) async {
        await context.setSessionID(sessionID)
    }

    public func clearSessionID() async {
        await context.clearSessionID()
    }

    public func setTraceID(_ traceID: String) async {
        await context.setTraceID(traceID)
    }

    public func withTraceID<T: Sendable>(
        _ traceID: String,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        try await context.withTraceID(traceID, operation: operation)
    }

    public func clearTraceID() async {
        await context.clearTraceID()
    }

    public func setContextMetadata(_ key: String, _ value: DiagnosticValue) async {
        await context.setMetadata(key, value)
    }

    public func setContextMetadata(_ key: String, _ value: String) async {
        await setContextMetadata(key, .string(value))
    }

    public func removeContextMetadata(_ key: String) async {
        await context.removeMetadata(key)
    }

    public func clearContextMetadata() async {
        await context.clearMetadata()
    }

    func removeContextMetadata(prefix: String) async {
        await context.removeMetadata(prefix: prefix)
    }

    public func setTrackingConsent(_ consent: DiagnosticsTrackingConsent) async {
        await captureState.setTrackingConsent(consent)
    }

    public func setCaptureEnabled(_ enabled: Bool) async {
        await captureState.setCaptureEnabled(enabled)
    }

    public func setSampleRate(_ sampleRate: Double) async {
        await captureState.setSampleRate(sampleRate)
    }
}
