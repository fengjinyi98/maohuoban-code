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

// DiagnosticsRegistry 全局运行时注册表
// 核心职责：
// - 串行化 SDK 安装与读取
// - 避免全局可变状态直接暴露给调用方
actor DiagnosticsRegistry {
    private var runtime: DiagnosticsRuntime?

    func install(_ configuration: DiagnosticsConfiguration) throws -> DiagnosticsRuntime {
        let runtime = try DiagnosticsRuntime(configuration: configuration)
        self.runtime = runtime
        DiagnosticsURLProtocol.runtime = runtime
        URLProtocol.registerClass(DiagnosticsURLProtocol.self)
        return runtime
    }

    func current() -> DiagnosticsRuntime? {
        runtime
    }
}

// DiagnosticsRuntime 诊断 SDK 运行时
// 核心职责：
// - 编排隐私策略、存储、清理、导出和网络配置入口
// - 作为产品侧一次接入后的稳定句柄
public final class DiagnosticsRuntime: @unchecked Sendable {
    private let configuration: DiagnosticsConfiguration
    private let store: FileSegmentStore
    private let context = DiagnosticsContext()
    private let exportRegistry = ExportDirectoryRegistry()
    private let startedAt = Date()

    init(configuration: DiagnosticsConfiguration) throws {
        self.configuration = configuration
        store = try FileSegmentStore(
            directory: configuration.storageDirectory,
            maxSegmentBytes: configuration.maxSegmentBytes
        )
    }

    public func record(_ event: DiagnosticEvent) async {
        let contextualEvent = await context.apply(to: event)
        let event = configuration.privacy.apply(
            to: contextualEvent
                .metadata("service", configuration.serviceName)
                .metadata("environment", configuration.environment)
        )
        try? await store.append(event)
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
        var event = DiagnosticEvent.performance("runtime snapshot")
            .metadata("process_id", "\(processInfo.processIdentifier)")
            .metadata("process_name", processInfo.processName)
            .metadata("os", processInfo.operatingSystemVersionString)
            .metadata("arch", runtimeArchitecture())
            .metadata("uptime_ms", "\(Int(Date().timeIntervalSince(startedAt) * 1_000))")
            .metadata("physical_memory_bytes", "\(processInfo.physicalMemory)")
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
        exportRegistry.register(bundle.directoryURL)
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

// ExportDirectoryRegistry 导出目录注册表
// 核心职责：
// - 记录当前运行时创建的 Debug Bundle 目录
// - 按清理策略删除过期导出包
final class ExportDirectoryRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var directories: [URL] = []

    func register(_ directory: URL) {
        lock.lock()
        directories.append(directory)
        lock.unlock()
    }

    func cleanup(policy: CleanupPolicy) throws -> CleanupReport {
        var report = CleanupReport()
        var remaining: [URL] = []
        lock.lock()
        let currentDirectories = directories
        directories.removeAll()
        lock.unlock()

        for directory in currentDirectories {
            guard FileManager.default.fileExists(atPath: directory.path) else {
                continue
            }
            let values = try directory.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = values.contentModificationDate ?? .distantPast
            if Date().timeIntervalSince(modified) >= policy.maxExportAge {
                report.freedBytes += UInt64(directorySize(directory))
                try FileManager.default.removeItem(at: directory)
                report.removedExports += 1
            } else {
                remaining.append(directory)
            }
        }

        lock.lock()
        directories.append(contentsOf: remaining)
        lock.unlock()
        return report
    }

    private func directorySize(_ directory: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }
        var total = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            total += values?.fileSize ?? 0
        }
        return total
    }
}

// DiagnosticsSpan 性能 span
// 核心职责：
// - 记录一段业务或系统操作的耗时
// - 将耗时作为 performance 事件写入统一时间线
public final class DiagnosticsSpan: @unchecked Sendable {
    private let name: String
    private weak var runtime: DiagnosticsRuntime?
    private let startedAt: Date

    init(name: String, runtime: DiagnosticsRuntime) {
        self.name = name
        self.runtime = runtime
        startedAt = Date()
    }

    public func end(metadata: [String: String] = [:]) async {
        let duration = Date().timeIntervalSince(startedAt)
        var event = DiagnosticEvent.performance(name)
            .metadata("duration_ms", "\(Int(duration * 1_000))")
        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        await runtime?.record(event)
    }
}
