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

    init(configuration: DiagnosticsConfiguration) throws {
        self.configuration = configuration
        store = try FileSegmentStore(
            directory: configuration.storageDirectory,
            maxSegmentBytes: configuration.maxSegmentBytes
        )
    }

    public func record(_ event: DiagnosticEvent) async {
        let event = configuration.privacy.apply(
            to: event
                .metadata("service", configuration.serviceName)
                .metadata("environment", configuration.environment)
        )
        try? await store.append(event)
    }

    public func log(_ severity: DiagnosticSeverity, _ message: String) async {
        await record(.log(severity, message))
    }

    public func flush() async throws {
        try await store.flush()
    }

    public func readEvents() async throws -> [DiagnosticEvent] {
        try await store.readAll()
    }

    public func cleanup() async throws -> CleanupReport {
        try await store.cleanup(configuration.cleanup)
    }

    public func exportDebugBundle(to outputDirectory: URL) async throws -> DebugBundle {
        try DebugBundleExporter(outputDirectory: outputDirectory)
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
