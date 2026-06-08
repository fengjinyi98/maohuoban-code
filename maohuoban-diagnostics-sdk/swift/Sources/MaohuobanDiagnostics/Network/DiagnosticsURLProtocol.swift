import Foundation

// DiagnosticsURLProtocol 网络采集协议
// 核心职责：
// - 记录 URLSession 请求的 URL、方法、耗时、状态码、载荷大小、响应类型和错误摘要
// - 为一次安装后的全局网络采集提供稳定入口
public final class DiagnosticsURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static weak var runtime: DiagnosticsRuntime?
    private static let handledKey = "MaohuobanDiagnosticsHandled"
    private var dataTask: URLSessionDataTask?
    private var startedAt = Date()
    private var loadedRequest: URLRequest?
    private let terminalEventLock = NSLock()
    private var recordedTerminalEvent = false

    public override class func canInit(with request: URLRequest) -> Bool {
        URLProtocol.property(forKey: handledKey, in: request) == nil
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    public static func instrumentedRequest(_ request: URLRequest) -> URLRequest {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return request
        }
        URLProtocol.setProperty(true, forKey: handledKey, in: mutableRequest)
        if mutableRequest.value(forHTTPHeaderField: "traceparent") == nil {
            mutableRequest.setValue(
                DiagnosticsTraceContext.generate().traceparent,
                forHTTPHeaderField: "traceparent"
            )
        }
        return mutableRequest as URLRequest
    }

    public override func startLoading() {
        startedAt = Date()
        let loadedRequest = Self.instrumentedRequest(request)
        self.loadedRequest = loadedRequest

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = []
        let session = URLSession(configuration: configuration)
        dataTask = session.dataTask(with: loadedRequest) { [weak self] data, response, error in
            guard let self else {
                return
            }
            self.record(response: response, data: data, error: error)
            if let response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
            } else {
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
        dataTask?.resume()
    }

    public override func stopLoading() {
        recordCancellation()
        dataTask?.cancel()
        dataTask = nil
    }

    private func record(response: URLResponse?, data: Data?, error: Error?) {
        guard markTerminalEventRecorded() else {
            return
        }
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
        let capturedSummary = Self.networkSummary(
            request: loadedRequest ?? request,
            response: response,
            data: data,
            error: error,
            durationMs: durationMs
        )
        let capturedRuntime = Self.runtime
        Task.detached { @Sendable [capturedSummary, capturedRuntime] in
            await capturedRuntime?.network(capturedSummary)
        }
    }

    private func recordCancellation() {
        guard markTerminalEventRecorded() else {
            return
        }
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
        let capturedSummary = Self.cancelledNetworkSummary(
            request: loadedRequest ?? request,
            durationMs: durationMs
        )
        let capturedRuntime = Self.runtime
        Task.detached { @Sendable [capturedSummary, capturedRuntime] in
            await capturedRuntime?.network(capturedSummary)
        }
    }

    // markTerminalEventRecorded 标记网络终态事件已记录
    // 核心职责：
    // - 保证完成、失败和取消三类终态只写入一次
    // - 隔离 URLSession 回调与 stopLoading 并发触发的竞态
    private func markTerminalEventRecorded() -> Bool {
        terminalEventLock.lock()
        defer {
            terminalEventLock.unlock()
        }
        guard !recordedTerminalEvent else {
            return false
        }
        recordedTerminalEvent = true
        return true
    }
}
