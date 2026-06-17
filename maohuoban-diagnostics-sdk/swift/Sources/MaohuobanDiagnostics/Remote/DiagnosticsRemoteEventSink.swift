import Foundation

// DiagnosticsRemoteEventSink 远端诊断事件镜像发送器
// 核心职责：
// - 将本地已采集事件异步回流到开发机 collector
// - 使用独立 URLSession 避免诊断请求再次触发全局网络采集
actor DiagnosticsRemoteEventSink {
    private let configuration: DiagnosticsRemoteMirrorConfiguration
    private let session: URLSession

    init(configuration: DiagnosticsRemoteMirrorConfiguration) {
        self.configuration = configuration
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = []
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeoutSeconds
        sessionConfiguration.timeoutIntervalForResource = configuration.timeoutSeconds
        session = URLSession(configuration: sessionConfiguration)
    }

    func append(_ event: DiagnosticEvent) async {
        do {
            let request = try Self.makeRequest(for: event, configuration: configuration)
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return
            }
        } catch {
            return
        }
    }

    static func makeRequest(
        for event: DiagnosticEvent,
        configuration: DiagnosticsRemoteMirrorConfiguration
    ) throws -> URLRequest {
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in configuration.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = try JSONEncoder.maohuobanDiagnostics.encode(event)
        return request
    }
}
