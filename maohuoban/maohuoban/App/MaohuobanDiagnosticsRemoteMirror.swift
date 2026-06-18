import Foundation
import MaohuobanDiagnostics

// MaohuobanDiagnosticsRemoteMirror 真机诊断回流配置
// 核心职责：
// - 为 Debug 真机把诊断事件镜像到开发机 collector
// - 支持环境变量覆盖接收端地址
enum MaohuobanDiagnosticsRemoteMirror {
    private static let endpointEnvironmentKey = "MAOHUOBAN_DIAGNOSTICS_REMOTE_INGEST_URL"
    private static let tokenEnvironmentKey = "MAOHUOBAN_DIAGNOSTICS_INGEST_TOKEN"
    private static let defaultToken = "maohuoban-local-diagnostics"
    private static let defaultIngestPath = "/internal/diagnostics/ingest"

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isSimulator: Bool = Self.isRunningOnSimulator
    ) -> DiagnosticsRemoteMirrorConfiguration? {
        #if DEBUG
        guard !isSimulator else {
            return nil
        }
        if let endpoint = environment[endpointEnvironmentKey],
           let url = URL(string: endpoint) {
            return configuration(endpoint: url, environment: environment)
        }
        guard var components = URLComponents(
            url: MHBBackendEndpoint.localDevelopmentBaseURL,
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }
        components.path = defaultIngestPath
        guard let url = components.url else {
            return nil
        }
        return configuration(endpoint: url, environment: environment)
        #else
        return nil
        #endif
    }

    private static func configuration(
        endpoint: URL,
        environment: [String: String]
    ) -> DiagnosticsRemoteMirrorConfiguration {
        DiagnosticsRemoteMirrorConfiguration(
            endpoint: endpoint,
            headers: [
                "X-Maohuoban-Diagnostics-Source": "ios-device-debug",
                "X-Maohuoban-Diagnostics-Token": environment[tokenEnvironmentKey] ?? defaultToken
            ],
            timeoutSeconds: 1
        )
    }

    private static var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
