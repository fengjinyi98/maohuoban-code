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
        dataTask?.cancel()
        dataTask = nil
    }

    private func record(response: URLResponse?, data: Data?, error: Error?) {
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
        let capturedSummary = Self.networkSummary(
            request: request,
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

    // networkSummary 构造网络采集摘要
    // 核心职责：
    // - 从 URLSession 请求、响应和错误中提取稳定调试字段
    // - 保持 URLProtocol 回调和测试共用同一采集边界
    static func networkSummary(
        request: URLRequest,
        response: URLResponse?,
        data: Data?,
        error: Error?,
        durationMs: Int
    ) -> NetworkSummary {
        var summary = NetworkSummary(
            method: request.httpMethod ?? "GET",
            url: request.url?.absoluteString ?? "",
            durationMs: durationMs,
            metadata: networkMetadata(request: request, response: response, data: data)
        )
        if let http = response as? HTTPURLResponse {
            summary.statusCode = http.statusCode
        }
        if let error {
            summary.error = error.localizedDescription
        }
        return summary
    }

    // networkMetadata 构造网络 metadata
    // 核心职责：
    // - 记录请求和响应体大小、响应类型和 header key
    // - 避免采集 header value，降低敏感信息外泄风险
    private static func networkMetadata(
        request: URLRequest,
        response: URLResponse?,
        data: Data?
    ) -> [String: String] {
        var metadata: [String: String] = [:]
        if let requestBodyBytes = request.httpBody?.count {
            metadata["request_body_bytes"] = "\(requestBodyBytes)"
        }
        if let responseBodyBytes = data?.count {
            metadata["response_body_bytes"] = "\(responseBodyBytes)"
        }
        if let mimeType = response?.mimeType, !mimeType.isEmpty {
            metadata["response_mime_type"] = mimeType
        }
        let requestHeaderKeys = sortedHeaderKeys(request.allHTTPHeaderFields)
        if !requestHeaderKeys.isEmpty {
            metadata["request_header_keys"] = requestHeaderKeys.joined(separator: ",")
        }
        if let http = response as? HTTPURLResponse {
            let responseHeaderKeys = http.allHeaderFields.keys
                .compactMap { $0 as? String }
                .sorted()
            if !responseHeaderKeys.isEmpty {
                metadata["response_header_keys"] = responseHeaderKeys.joined(separator: ",")
            }
        }
        return metadata
    }

    // sortedHeaderKeys 规范化请求 header key
    // 核心职责：
    // - 只保留 header 名称，避免采集敏感 header 值
    // - 提供稳定排序，便于测试和跨事件对比
    private static func sortedHeaderKeys(_ headers: [String: String]?) -> [String] {
        (headers ?? [:]).keys.sorted()
    }
}
