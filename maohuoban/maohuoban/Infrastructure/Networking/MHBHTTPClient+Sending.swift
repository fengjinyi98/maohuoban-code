import Foundation

// MHBHTTPClient 发送与响应解析
// 核心职责：
// - 统一执行 URLSession 请求并写入追踪头
// - 解析后端标准响应并映射认证失效事件
extension MHBHTTPClient {
    func send<ResponseBody: Decodable>(
        _ request: URLRequest
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        var request = request
        instrumentTraceHeaders(for: &request)
        let startedAt = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            await recordNetworkSummary(
                request: request,
                response: nil,
                responseData: nil,
                startedAt: startedAt,
                error: error.localizedDescription
            )
            throw .transport(error.localizedDescription)
        }

        return try await decodeResponse(
            data: data,
            response: response,
            request: request,
            startedAt: startedAt
        )
    }

    func decodeResponse<ResponseBody: Decodable>(
        data: Data,
        response: URLResponse,
        request: URLRequest,
        requestBodyBytes: Int? = nil,
        startedAt: Date
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        guard let httpResponse = response as? HTTPURLResponse else {
            await recordNetworkSummary(
                request: request,
                response: response,
                responseData: data,
                requestBodyBytes: requestBodyBytes,
                startedAt: startedAt,
                error: "invalid_response"
            )
            throw .invalidResponse
        }

        do {
            let apiResponse = try decoder.decode(MHBAPIResponse<ResponseBody>.self, from: data)
            await recordNetworkSummary(
                request: request,
                response: response,
                responseData: data,
                requestBodyBytes: requestBodyBytes,
                startedAt: startedAt,
                apiCode: apiResponse.code,
                apiSuccess: apiResponse.success,
                error: apiResponse.success ? nil : "api_response_failed"
            )
            if apiResponse.success, (200..<300).contains(httpResponse.statusCode) {
                return apiResponse
            }
            let apiError = MHBAPIError.business(
                code: apiResponse.code,
                message: apiResponse.message,
                statusCode: httpResponse.statusCode
            )
            postAuthenticationInvalidationIfNeeded(apiError)
            throw apiError
        } catch let apiError as MHBAPIError {
            throw apiError
        } catch {
            await recordNetworkSummary(
                request: request,
                response: response,
                responseData: data,
                requestBodyBytes: requestBodyBytes,
                startedAt: startedAt,
                error: "decode_failed"
            )
            throw .decoding(error.localizedDescription)
        }
    }

    private func postAuthenticationInvalidationIfNeeded(_ error: MHBAPIError) {
        guard error.isAuthenticationInvalidation else {
            return
        }
        NotificationCenter.default.post(
            name: .mhbAuthenticationInvalidated,
            object: error.toastMessage
        )
    }

    func instrumentTraceHeaders(for request: inout URLRequest) {
        if request.value(forHTTPHeaderField: "traceparent") == nil {
            request.setValue(Self.generateTraceparent(), forHTTPHeaderField: "traceparent")
        }
        if request.value(forHTTPHeaderField: "x-request-id") == nil {
            request.setValue(UUID().uuidString, forHTTPHeaderField: "x-request-id")
        }
    }

    private static func generateTraceparent() -> String {
        let traceID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let spanID = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)).lowercased()
        return "00-\(traceID)-\(spanID)-01"
    }
}
