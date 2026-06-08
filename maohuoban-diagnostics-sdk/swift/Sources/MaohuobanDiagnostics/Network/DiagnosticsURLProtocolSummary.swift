import Foundation

extension DiagnosticsURLProtocol {
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
        if let error, isCancelledError(error) {
            return cancelledNetworkSummary(request: request, durationMs: durationMs)
        }
        var summary = NetworkSummary(
            method: request.httpMethod ?? "GET",
            url: request.url?.absoluteString ?? "",
            durationMs: durationMs,
            traceparent: request.value(forHTTPHeaderField: "traceparent"),
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

    // cancelledNetworkSummary 构造网络取消摘要
    // 核心职责：
    // - 在 URLProtocol 停止加载时保留取消信号
    // - 避免取消请求在诊断时间线中丢失
    static func cancelledNetworkSummary(request: URLRequest, durationMs: Int) -> NetworkSummary {
        NetworkSummary(
            method: request.httpMethod ?? "GET",
            url: request.url?.absoluteString ?? "",
            durationMs: durationMs,
            traceparent: request.value(forHTTPHeaderField: "traceparent"),
            metadata: networkMetadata(request: request, response: nil, data: nil)
                .merging(["cancelled": "true"]) { _, new in new }
        )
    }

    // isCancelledError 判断 URLSession 取消错误
    // 核心职责：
    // - 识别 Swift URLProtocol 和 URLSession 回调中的取消信号
    // - 保持取消事件与网络失败事件的诊断语义分离
    private static func isCancelledError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .cancelled
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
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
