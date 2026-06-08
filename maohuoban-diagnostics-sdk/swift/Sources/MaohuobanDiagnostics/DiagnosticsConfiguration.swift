import Foundation

// DiagnosticsConfiguration SDK 安装配置
// 核心职责：
// - 汇总服务名、环境、存储目录、隐私和清理策略
// - 作为一次全局安装入口的声明式配置
public struct DiagnosticsConfiguration: Sendable {
    public var serviceName: String
    public var environment: String
    public var storageDirectory: URL
    public var privacy: PrivacyPolicy
    public var capture: CapturePolicy
    public var cleanup: CleanupPolicy
    public var maxSegmentBytes: UInt64

    public init(
        serviceName: String,
        environment: String,
        storageDirectory: URL = DiagnosticsConfiguration.defaultStorageDirectory(),
        privacy: PrivacyPolicy = .init(),
        capture: CapturePolicy = .init(),
        cleanup: CleanupPolicy = .init(),
        maxSegmentBytes: UInt64 = 1_024 * 1_024
    ) {
        self.serviceName = serviceName
        self.environment = environment
        self.storageDirectory = storageDirectory
        self.privacy = privacy
        self.capture = capture
        self.cleanup = cleanup
        self.maxSegmentBytes = maxSegmentBytes
    }

    public static func defaultStorageDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "MaohuobanDiagnostics/segments")
    }
}

// DiagnosticsBootstrapConfiguration SDK 启动接入配置
// 核心职责：
// - 将安装配置、默认上下文和启动采集策略合并为一个声明式入口
// - 降低 App 启动阶段重复拼装诊断管线的成本
public struct DiagnosticsBootstrapConfiguration: Sendable {
    public var installation: DiagnosticsConfiguration
    public var defaults: [String: String]
    public var sessionID: String?
    public var traceID: String?
    public var captureRuntimeSnapshot: Bool
    public var cleanupOnBootstrap: Bool

    public init(
        serviceName: String,
        environment: String,
        storageDirectory: URL = DiagnosticsConfiguration.defaultStorageDirectory(),
        privacy: PrivacyPolicy = .init(),
        capture: CapturePolicy = .init(),
        cleanup: CleanupPolicy = .init(),
        maxSegmentBytes: UInt64 = 1_024 * 1_024,
        defaults: [String: String] = [:],
        sessionID: String? = nil,
        traceID: String? = nil,
        captureRuntimeSnapshot: Bool = true,
        cleanupOnBootstrap: Bool = true
    ) {
        installation = DiagnosticsConfiguration(
            serviceName: serviceName,
            environment: environment,
            storageDirectory: storageDirectory,
            privacy: privacy,
            capture: capture,
            cleanup: cleanup,
            maxSegmentBytes: maxSegmentBytes
        )
        self.defaults = defaults
        self.sessionID = sessionID
        self.traceID = traceID
        self.captureRuntimeSnapshot = captureRuntimeSnapshot
        self.cleanupOnBootstrap = cleanupOnBootstrap
    }
}
