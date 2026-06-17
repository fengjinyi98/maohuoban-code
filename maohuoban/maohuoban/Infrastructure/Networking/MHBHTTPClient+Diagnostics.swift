import Foundation
import MaohuobanDiagnostics

extension MHBHTTPClient {
    // recordNetworkSummary 记录 HTTP 网络摘要
    // 核心职责：
    // - 在 MHBHTTPClient 统一补齐 network 事件
    // - 全局 URLProtocol 已启用时避免重复采集
    func recordNetworkSummary(
        request: URLRequest,
        response: URLResponse?,
        responseData: Data?,
        requestBodyBytes: Int? = nil,
        startedAt: Date,
        apiCode: String? = nil,
        apiSuccess: Bool? = nil,
        error: String? = nil
    ) async {
        guard await Diagnostics.isGlobalNetworkCaptureRegistered == false else {
            return
        }
        var metadata = networkMetadata(
            request: request,
            response: response,
            responseData: responseData,
            requestBodyBytes: requestBodyBytes
        )
        if let apiCode {
            metadata["api_code"] = .string(apiCode)
        }
        if let apiSuccess {
            metadata["api_success"] = .bool(apiSuccess)
        }
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
        let summary = NetworkSummary(
            method: request.httpMethod ?? "GET",
            url: request.url?.absoluteString ?? "",
            statusCode: (response as? HTTPURLResponse)?.statusCode,
            durationMs: durationMs,
            error: error,
            traceparent: request.value(forHTTPHeaderField: "traceparent"),
            metadata: metadata
        )
        await Diagnostics.network(summary)
    }

    private func networkMetadata(
        request: URLRequest,
        response: URLResponse?,
        responseData: Data?,
        requestBodyBytes: Int?
    ) -> DiagnosticProperties {
        var metadata: DiagnosticProperties = [:]
        if let requestBodyBytes = requestBodyBytes ?? request.httpBody?.count {
            metadata["request_body_bytes"] = .int(requestBodyBytes)
        }
        if let responseBodyBytes = responseData?.count {
            metadata["response_body_bytes"] = .int(responseBodyBytes)
        }
        if let mimeType = response?.mimeType, !mimeType.isEmpty {
            metadata["response_mime_type"] = .string(mimeType)
        }
        let requestHeaderKeys = (request.allHTTPHeaderFields ?? [:]).keys.sorted()
        if !requestHeaderKeys.isEmpty {
            metadata["request_header_keys"] = .string(requestHeaderKeys.joined(separator: ","))
        }
        if let httpResponse = response as? HTTPURLResponse {
            let responseHeaderKeys = httpResponse.allHeaderFields.keys
                .compactMap { $0 as? String }
                .sorted()
            if !responseHeaderKeys.isEmpty {
                metadata["response_header_keys"] = .string(responseHeaderKeys.joined(separator: ","))
            }
        }
        return metadata
    }
}

extension MHBAPIError {
    var diagnosticsSummary: String {
        switch self {
        case .transport:
            "transport"
        case .business(let code, _, _):
            code
        case .decoding:
            "decoding"
        case .invalidResponse:
            "invalid_response"
        }
    }
}
