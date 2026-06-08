// NetworkSummary 网络请求摘要
// 核心职责：
// - 承载 HTTP/RPC 请求的关键调试字段
// - 生成统一 network 诊断事件
public struct NetworkSummary: Sendable {
    public var method: String
    public var url: String
    public var statusCode: Int?
    public var durationMs: Int?
    public var error: String?
    public var traceparent: String?
    public var metadata: DiagnosticProperties

    public init(
        method: String,
        url: String,
        statusCode: Int? = nil,
        durationMs: Int? = nil,
        error: String? = nil,
        traceparent: String? = nil,
        metadata: DiagnosticProperties = [:]
    ) {
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.durationMs = durationMs
        self.error = error
        self.traceparent = traceparent
        self.metadata = metadata
    }

    func event() -> DiagnosticEvent {
        var metadata = metadata
        let failedStatus = statusCode.map { $0 >= 400 } ?? false
        let cancelled = metadata["cancelled"]?.stringValue == "true"
        metadata["method"] = .string(method)
        metadata["url"] = .string(url)
        metadata["http.request.method"] = .string(method)
        metadata["url.full"] = .string(url)
        if let statusCode {
            metadata["status_code"] = .string("\(statusCode)")
            metadata["http.response.status_code"] = .string("\(statusCode)")
        }
        if let durationMs {
            metadata["duration_ms"] = .string("\(durationMs)")
        }
        if let error {
            metadata["error"] = .string(error)
        }
        if let traceparent {
            metadata["traceparent"] = .string(traceparent)
        }
        return DiagnosticEvent(
            kind: .network,
            severity: cancelled ? .warn : (error == nil && !failedStatus ? .info : .error),
            message: cancelled ? "network request cancelled" : (error == nil && !failedStatus ? "network request completed" : "network request failed"),
            metadata: metadata
        )
    }
}
