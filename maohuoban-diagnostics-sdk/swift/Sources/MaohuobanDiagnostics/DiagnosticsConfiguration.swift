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
    public var cleanup: CleanupPolicy
    public var maxSegmentBytes: UInt64

    public init(
        serviceName: String,
        environment: String,
        storageDirectory: URL = DiagnosticsConfiguration.defaultStorageDirectory(),
        privacy: PrivacyPolicy = .init(),
        cleanup: CleanupPolicy = .init(),
        maxSegmentBytes: UInt64 = 1_024 * 1_024
    ) {
        self.serviceName = serviceName
        self.environment = environment
        self.storageDirectory = storageDirectory
        self.privacy = privacy
        self.cleanup = cleanup
        self.maxSegmentBytes = maxSegmentBytes
    }

    public static func defaultStorageDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "MaohuobanDiagnostics/segments")
    }
}
