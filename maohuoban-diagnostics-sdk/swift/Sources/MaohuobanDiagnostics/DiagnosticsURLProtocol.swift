import Foundation

// DiagnosticsURLProtocol 网络采集协议
// 核心职责：
// - 记录 URLSession 请求的 URL、方法、耗时、状态码和错误摘要
// - 为一次安装后的全局网络采集提供稳定入口
public final class DiagnosticsURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static weak var runtime: DiagnosticsRuntime?
    private static let handledKey = "MaohuobanDiagnosticsHandled"
    private var dataTask: URLSessionDataTask?
    private var startedAt = Date()

    public override class func canInit(with request: URLRequest) -> Bool {
        URLProtocol.property(forKey: handledKey, in: request) == nil
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    public override func startLoading() {
        startedAt = Date()
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = []
        let session = URLSession(configuration: configuration)
        dataTask = session.dataTask(with: mutableRequest as URLRequest) { [weak self] data, response, error in
            guard let self else {
                return
            }
            self.record(response: response, error: error)
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
        dataTask?.cancel()
        dataTask = nil
    }

    private func record(response: URLResponse?, error: Error?) {
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
        var summary = NetworkSummary(
            method: request.httpMethod ?? "GET",
            url: request.url?.absoluteString ?? "",
            durationMs: durationMs
        )
        if let http = response as? HTTPURLResponse {
            summary.statusCode = http.statusCode
        }
        if let error {
            summary.error = error.localizedDescription
        }
        let capturedSummary = summary
        let capturedRuntime = Self.runtime
        Task.detached { @Sendable [capturedSummary, capturedRuntime] in
            await capturedRuntime?.network(capturedSummary)
        }
    }
}
