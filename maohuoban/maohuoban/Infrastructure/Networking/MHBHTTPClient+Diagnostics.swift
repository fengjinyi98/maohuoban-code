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
            url: request.url.map(MHBHTTPNetworkSummaryBuilder.redactedURLString(from:)) ?? "",
            statusCode: (response as? HTTPURLResponse)?.statusCode,
            durationMs: durationMs,
            error: error,
            traceparent: request.value(forHTTPHeaderField: MHBHTTPHeader.traceparent),
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
        for (key, value) in MHBHTTPNetworkSummaryBuilder.metadata(
            request: request,
            response: response,
            responseData: responseData,
            requestBodyBytes: requestBodyBytes
        ) {
            if let intValue = Int(value) {
                metadata[key] = .int(intValue)
            } else {
                metadata[key] = .string(value)
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
