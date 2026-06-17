import Foundation
import MaohuobanDiagnostics

// MaohuobanDiagnosticsRemoteMirror 真机诊断回流配置
// 核心职责：
// - 为 Debug 真机把诊断事件镜像到开发机 collector
// - 支持环境变量覆盖接收端地址
enum MaohuobanDiagnosticsRemoteMirror {
    private static let endpointEnvironmentKey = "MAOHUOBAN_DIAGNOSTICS_REMOTE_INGEST_URL"
    private static let defaultCollectorPort = 18081

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DiagnosticsRemoteMirrorConfiguration? {
        #if DEBUG
        #if targetEnvironment(simulator)
        return nil
        #else
        if let endpoint = environment[endpointEnvironmentKey],
           let url = URL(string: endpoint) {
            return configuration(endpoint: url)
        }
        guard var components = URLComponents(
            url: MHBBackendEndpoint.localDevelopmentBaseURL,
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }
        components.port = defaultCollectorPort
        components.path = "/ingest"
        guard let url = components.url else {
            return nil
        }
        return configuration(endpoint: url)
        #endif
        #else
        return nil
        #endif
    }

    private static func configuration(endpoint: URL) -> DiagnosticsRemoteMirrorConfiguration {
        DiagnosticsRemoteMirrorConfiguration(
            endpoint: endpoint,
            headers: ["X-Maohuoban-Diagnostics-Source": "ios-device-debug"],
            timeoutSeconds: 1
        )
    }
}
