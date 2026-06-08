import Foundation

// Diagnostics SDK 全局入口
// 核心职责：
// - 提供一次 install 后全局可用的诊断能力
// - 管理声明式配置与运行时句柄
public enum Diagnostics {
    public static let sdkVersion = "0.1.0"
    private static let registry = DiagnosticsRegistry()

    @discardableResult
    public static func install(_ configuration: DiagnosticsConfiguration) async throws -> DiagnosticsRuntime {
        try await registry.install(configuration)
    }

    @discardableResult
    public static func bootstrap(_ configuration: DiagnosticsBootstrapConfiguration) async throws -> DiagnosticsRuntime {
        let runtime = try await install(configuration.installation)
        if configuration.cleanupOnBootstrap {
            _ = try await runtime.cleanup()
        }
        if let sessionID = configuration.sessionID {
            await runtime.setSessionID(sessionID)
        }
        if let traceID = configuration.traceID {
            await runtime.setTraceID(traceID)
        }
        for (key, value) in configuration.defaults {
            await runtime.setContextMetadata(key, value)
        }
        await runtime.record(.init(kind: .lifecycle, severity: .info, message: "diagnostics bootstrap completed"))
        if configuration.captureRuntimeSnapshot {
            await runtime.captureRuntimeSnapshot(metadata: ["phase": "bootstrap"])
        }
        return runtime
    }

    public static func current() async -> DiagnosticsRuntime? {
        await registry.current()
    }

    public static func log(_ severity: DiagnosticSeverity, _ message: String) async {
        await current()?.log(severity, message)
    }

    public static func record(_ event: DiagnosticEvent) async {
        await current()?.record(event)
    }

    public static func breadcrumb(_ message: String, metadata: [String: String] = [:]) async {
        await current()?.breadcrumb(message, metadata: metadata)
    }

    public static func error(_ message: String, metadata: [String: String] = [:]) async {
        await current()?.error(message, metadata: metadata)
    }

    public static func captureError(_ error: Error, metadata: [String: String] = [:]) async {
        await current()?.captureError(error, metadata: metadata)
    }

    public static func network(_ summary: NetworkSummary) async {
        await current()?.network(summary)
    }

    public static func captureRuntimeSnapshot(metadata: [String: String] = [:]) async {
        await current()?.captureRuntimeSnapshot(metadata: metadata)
    }

    public static func setSessionID(_ sessionID: String) async {
        await current()?.setSessionID(sessionID)
    }

    public static func clearSessionID() async {
        await current()?.clearSessionID()
    }

    public static func setTraceID(_ traceID: String) async {
        await current()?.setTraceID(traceID)
    }

    public static func withTraceID<T: Sendable>(
        _ traceID: String,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        guard let runtime = await current() else {
            return try await operation()
        }
        return try await runtime.withTraceID(traceID, operation: operation)
    }

    public static func clearTraceID() async {
        await current()?.clearTraceID()
    }

    public static func setContextMetadata(_ key: String, _ value: String) async {
        await current()?.setContextMetadata(key, value)
    }

    public static func removeContextMetadata(_ key: String) async {
        await current()?.removeContextMetadata(key)
    }

    public static func clearContextMetadata() async {
        await current()?.clearContextMetadata()
    }

    public static func setTrackingConsent(_ consent: DiagnosticsTrackingConsent) async {
        await current()?.setTrackingConsent(consent)
    }

    public static func setCaptureEnabled(_ enabled: Bool) async {
        await current()?.setCaptureEnabled(enabled)
    }

    public static func setSampleRate(_ sampleRate: Double) async {
        await current()?.setSampleRate(sampleRate)
    }

    public static func beginSpan(_ name: String) async -> DiagnosticsSpan? {
        await current()?.beginSpan(name)
    }

    public static func flush() async throws {
        try await current()?.flush()
    }

    public static func cleanup() async throws -> CleanupReport? {
        try await current()?.cleanup()
    }

    public static func exportDebugBundle(to outputDirectory: URL) async throws -> DebugBundle? {
        try await current()?.exportDebugBundle(to: outputDirectory)
    }

    public static func exportLLMPrompt(title: String, maxEvents: Int = 200) async throws -> String? {
        try await current()?.exportLLMPrompt(title: title, maxEvents: maxEvents)
    }
}
