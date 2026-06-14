import Foundation
import MaohuobanDiagnostics

// MaohuobanDiagnosticsStorageDirectory 诊断存储目录解析器
// 核心职责：
// - 让 Debug 模拟器诊断报告直接写入仓库工作区
// - 支持通过环境变量显式指定 SDK 段文件目录
enum MaohuobanDiagnosticsStorageDirectory {
    static let segmentsEnvironmentKey = "MAOHUOBAN_DIAGNOSTICS_SEGMENTS_DIR"

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        sourceFilePath: String = #filePath
    ) -> URL {
        if let path = environment[segmentsEnvironmentKey], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }

        #if DEBUG && targetEnvironment(simulator)
        return workspaceSegmentsDirectory(sourceFilePath: sourceFilePath)
        #else
        return DiagnosticsConfiguration.defaultStorageDirectory()
        #endif
    }

    static func workspaceSegmentsDirectory(sourceFilePath: String) -> URL {
        var url = URL(fileURLWithPath: sourceFilePath)
        for _ in 0..<4 {
            url.deleteLastPathComponent()
        }
        return url
            .appendingPathComponent(".maohuoban-diagnostics")
            .appendingPathComponent("segments")
    }
}
