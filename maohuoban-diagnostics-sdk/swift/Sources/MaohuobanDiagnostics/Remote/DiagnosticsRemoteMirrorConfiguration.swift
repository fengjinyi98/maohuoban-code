import Foundation

// DiagnosticsRemoteMirrorConfiguration 远端诊断镜像配置
// 核心职责：
// - 描述 Debug 真机诊断事件回流到开发机的接收端
// - 为请求超时和附加头提供稳定配置入口
public struct DiagnosticsRemoteMirrorConfiguration: Sendable, Equatable {
    public var endpoint: URL
    public var headers: [String: String]
    public var timeoutSeconds: TimeInterval
    public var maxBatchEvents: Int
    public var maxBatchBytes: Int

    public init(
        endpoint: URL,
        headers: [String: String] = [:],
        timeoutSeconds: TimeInterval = 1,
        maxBatchEvents: Int = 20,
        maxBatchBytes: Int = 192 * 1_024
    ) {
        self.endpoint = endpoint
        self.headers = headers
        self.timeoutSeconds = timeoutSeconds
        self.maxBatchEvents = max(1, maxBatchEvents)
        self.maxBatchBytes = max(512, maxBatchBytes)
    }
}
