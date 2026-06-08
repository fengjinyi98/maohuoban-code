import Foundation

// DiagnosticsTraceContext W3C Trace Context
// 核心职责：
// - 表达可注入 HTTP 请求的 traceparent 值
// - 为网络事件提供标准链路字段
public struct DiagnosticsTraceContext: Sendable, Equatable {
    public var traceID: String
    public var spanID: String
    public var sampled: Bool

    public init(traceID: String, spanID: String, sampled: Bool = true) {
        self.traceID = traceID.lowercased()
        self.spanID = spanID.lowercased()
        self.sampled = sampled
    }

    public var traceparent: String {
        "00-\(traceID)-\(spanID)-\(sampled ? "01" : "00")"
    }

    public static func generate(sampled: Bool = true) -> DiagnosticsTraceContext {
        DiagnosticsTraceContext(
            traceID: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            spanID: String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)).lowercased(),
            sampled: sampled
        )
    }
}
