import Foundation

// DiagnosticsRuntime 诊断 SDK 运行时
// 核心职责：
// - 持有一次安装后的共享运行时状态
// - 为 capture、context、storage、export、network 扩展提供稳定基础
public final class DiagnosticsRuntime: @unchecked Sendable {
    let configuration: DiagnosticsConfiguration
    let store: FileSegmentStore
    let context = DiagnosticsContext()
    let captureState: DiagnosticsCaptureState
    let storageHealth = DiagnosticsStorageHealth()
    let exportRegistry: ExportDirectoryRegistry
    let startedAt = Date()

    init(configuration: DiagnosticsConfiguration) throws {
        self.configuration = configuration
        captureState = DiagnosticsCaptureState(policy: configuration.capture)
        exportRegistry = ExportDirectoryRegistry(
            indexURL: configuration.storageDirectory.appendingPathComponent(".debug-bundles.jsonl")
        )
        store = try FileSegmentStore(
            directory: configuration.storageDirectory,
            maxSegmentBytes: configuration.maxSegmentBytes
        )
    }
}
