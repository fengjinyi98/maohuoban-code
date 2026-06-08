import Foundation

// DiagnosticsRuntime 诊断 SDK 运行时
// 核心职责：
// - 编排隐私策略、存储、清理、导出和网络配置入口
// - 作为产品侧一次接入后的稳定句柄
public final class DiagnosticsRuntime: @unchecked Sendable {
    private let configuration: DiagnosticsConfiguration
    private let store: FileSegmentStore
    private let context = DiagnosticsContext()
    private let storageHealth = DiagnosticsStorageHealth()
    private let exportRegistry: ExportDirectoryRegistry
    private let startedAt = Date()

    init(configuration: DiagnosticsConfiguration) throws {
        self.configuration = configuration
        exportRegistry = ExportDirectoryRegistry(
            indexURL: configuration.storageDirectory.appending(path: ".debug-bundles.jsonl")
        )
        store = try FileSegmentStore(
            directory: configuration.storageDirectory,
            maxSegmentBytes: configuration.maxSegmentBytes
        )
    }

    public func record(_ event: DiagnosticEvent) async {
        let contextualEvent = await context.apply(to: event)
        guard let capturedEvent = configuration.capture.apply(
            to: contextualEvent
                .metadata("service", configuration.serviceName)
                .metadata("environment", configuration.environment)
        ) else {
            return
        }
        let event = configuration.privacy.apply(to: capturedEvent)
        do {
            try await store.append(event)
        } catch {
            await storageHealth.recordDroppedEvent(error)
        }
    }

    public func log(_ severity: DiagnosticSeverity, _ message: String) async {
        await record(.log(severity, message))
    }

    public func breadcrumb(_ message: String, metadata: [String: String] = [:]) async {
        var event = DiagnosticEvent(kind: .breadcrumb, severity: .info, message: message)
        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        await record(event)
    }

    public func error(_ message: String, metadata: [String: String] = [:]) async {
        var event = DiagnosticEvent.error(message)
        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        await record(event)
    }

    public func captureError(_ error: Error, metadata: [String: String] = [:]) async {
        var event = DiagnosticEvent.error(error.localizedDescription)
        let nsError = error as NSError
        event = event
            .metadata("error", error.localizedDescription)
            .metadata("error_type", String(reflecting: type(of: error)))
            .metadata("error_domain", nsError.domain)
            .metadata("error_code", "\(nsError.code)")
            .metadata("error_description", nsError.localizedDescription)

        let underlyingErrors = underlyingErrorDescriptions(from: nsError)
        if !underlyingErrors.isEmpty {
            event = event.metadata("underlying_errors", underlyingErrors.joined(separator: " | "))
        }

        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        await record(event)
    }

    public func network(_ summary: NetworkSummary) async {
        await record(summary.event())
    }

    public func captureRuntimeSnapshot(metadata: [String: String] = [:]) async {
        let processInfo = ProcessInfo.processInfo
        let storageStatus = await storageHealth.snapshot()
        var event = DiagnosticEvent.performance("runtime snapshot")
            .metadata("process_id", "\(processInfo.processIdentifier)")
            .metadata("process_name", processInfo.processName)
            .metadata("os", processInfo.operatingSystemVersionString)
            .metadata("arch", runtimeArchitecture())
            .metadata("uptime_ms", "\(Int(Date().timeIntervalSince(startedAt) * 1_000))")
            .metadata("physical_memory_bytes", "\(processInfo.physicalMemory)")
        if storageStatus.droppedEventCount > 0 {
            event = event
                .metadata("dropped_event_count", "\(storageStatus.droppedEventCount)")
                .metadata("last_storage_error", storageStatus.lastStorageError)
        }
        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        await record(event)
    }

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

    public func setContextMetadata(_ key: String, _ value: String) async {
        await context.setMetadata(key, value)
    }

    public func removeContextMetadata(_ key: String) async {
        await context.removeMetadata(key)
    }

    public func clearContextMetadata() async {
        await context.clearMetadata()
    }

    public func flush() async throws {
        try await store.flush()
    }

    public func readEvents() async throws -> [DiagnosticEvent] {
        try await store.readAll()
    }

    public func cleanup() async throws -> CleanupReport {
        var report = try await store.cleanup(configuration.cleanup)
        let exportReport = try exportRegistry.cleanup(policy: configuration.cleanup)
        report.removedExports += exportReport.removedExports
        report.freedBytes += exportReport.freedBytes
        return report
    }

    public func exportDebugBundle(to outputDirectory: URL) async throws -> DebugBundle {
        let bundle = try DebugBundleExporter(outputDirectory: outputDirectory)
            .export(events: try await readEvents())
        try exportRegistry.register(bundle.directoryURL)
        return bundle
    }

    public func exportLLMPrompt(title: String, maxEvents: Int = 200) async throws -> String {
        LLMPromptExporter(title: title, maxEvents: maxEvents)
            .export(events: try await readEvents())
    }

    public func instrumentedURLSessionConfiguration(
        _ base: URLSessionConfiguration = .default
    ) -> URLSessionConfiguration {
        let configuration = base
        var protocolClasses = configuration.protocolClasses ?? []
        protocolClasses.removeAll { $0 == DiagnosticsURLProtocol.self }
        protocolClasses.insert(DiagnosticsURLProtocol.self, at: 0)
        configuration.protocolClasses = protocolClasses
        return configuration
    }

    public func beginSpan(_ name: String) -> DiagnosticsSpan {
        DiagnosticsSpan(name: name, runtime: self)
    }

    private func underlyingErrorDescriptions(from error: NSError) -> [String] {
        var descriptions: [String] = []
        var current = error.userInfo[NSUnderlyingErrorKey] as? NSError
        while let error = current {
            descriptions.append("\(error.domain):\(error.code): \(error.localizedDescription)")
            current = error.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return descriptions
    }

    private func runtimeArchitecture() -> String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #elseif arch(arm)
        "arm"
        #elseif arch(i386)
        "i386"
        #else
        "unknown"
        #endif
    }
}
