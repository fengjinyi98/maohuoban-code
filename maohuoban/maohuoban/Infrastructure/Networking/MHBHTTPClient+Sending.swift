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
        try prepareRequest(&request)
        let startedAt = Date()
        return try await sendWithRetry(request, startedAt: startedAt)
    }

    private func sendWithRetry<ResponseBody: Decodable>(
        _ request: URLRequest,
        startedAt: Date,
        allowsTokenRefresh: Bool = true
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        var attempt = 1
        while true {
            do {
                return try await sendOnce(
                    request,
                    startedAt: startedAt,
                    attempt: attempt
                )
            } catch let retryableError as MHBHTTPRetryableError {
                guard attempt < retryPolicy.maxAttempts else {
                    return try await decodeResponse(
                        data: retryableError.data,
                        response: retryableError.response,
                        request: request,
                        startedAt: startedAt
                    )
                }
                await recordNetworkSummary(
                    request: request,
                    response: retryableError.response,
                    responseData: retryableError.data,
                    startedAt: startedAt,
                    error: "retryable_status_\(retryableError.response.statusCode)"
                )
                await sleepBeforeRetry(attempt: attempt)
                attempt += 1
            } catch let apiError as MHBAPIError {
                guard allowsTokenRefresh,
                      apiError.shouldAttemptTokenRefresh,
                      let tokenRefreshHandler else {
                    postAuthenticationInvalidationIfNeeded(apiError)
                    throw apiError
                }
                do {
                    var replayRequest = request
                    let headers = try await tokenRefreshHandler.refreshAuthorizationHeaders()
                    for (field, value) in headers {
                        replayRequest.setValue(value, forHTTPHeaderField: field)
                    }
                    return try await sendWithRetry(
                        replayRequest,
                        startedAt: Date(),
                        allowsTokenRefresh: false
                    )
                } catch {
                    postAuthenticationInvalidationIfNeeded(error)
                    throw error
                }
            } catch {
                guard retryPolicy.shouldRetry(error: error, request: request),
                      attempt < retryPolicy.maxAttempts else {
                    await recordNetworkSummary(
                        request: request,
                        response: nil,
                        responseData: nil,
                        startedAt: startedAt,
                        error: error.localizedDescription
                    )
                    throw .transport(error.localizedDescription)
                }
                await recordNetworkSummary(
                    request: request,
                    response: nil,
                    responseData: nil,
                    startedAt: startedAt,
                    error: "retryable_transport"
                )
                await sleepBeforeRetry(attempt: attempt)
                attempt += 1
            }
        }
    }

    private func sendOnce<ResponseBody: Decodable>(
        _ request: URLRequest,
        startedAt: Date,
        attempt: Int
    ) async throws -> MHBAPIResponse<ResponseBody> {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw error
        }

        if let httpResponse = response as? HTTPURLResponse,
           retryPolicy.shouldRetry(response: httpResponse, request: request),
           attempt < retryPolicy.maxAttempts {
            throw MHBHTTPRetryableError(response: httpResponse, data: data)
        }

        return try await decodeResponse(
            data: data,
            response: response,
            request: request,
            startedAt: startedAt,
            postsAuthenticationInvalidation: false
        )
    }

    private func sleepBeforeRetry(attempt: Int) async {
        let delay = retryPolicy.delayBeforeRetry(afterAttempt: attempt)
        guard delay > 0 else {
            return
        }
        try? await Task.sleep(for: .seconds(delay))
    }

    func decodeResponse<ResponseBody: Decodable>(
        data: Data,
        response: URLResponse,
        request: URLRequest,
        requestBodyBytes: Int? = nil,
        startedAt: Date,
        postsAuthenticationInvalidation: Bool = true
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
            if postsAuthenticationInvalidation {
                postAuthenticationInvalidationIfNeeded(apiError)
            }
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

    func prepareRequest(_ request: inout URLRequest) throws(MHBAPIError) {
        if request.value(forHTTPHeaderField: MHBHTTPHeader.authorization) == nil,
           let authorizationProvider {
            let headers = try authorizationProvider.authorizationHeaders()
            for (field, value) in headers {
                request.setValue(value, forHTTPHeaderField: field)
            }
        }
        instrumentTraceHeaders(for: &request)
        instrumentIdempotencyHeader(for: &request)
    }

    func instrumentTraceHeaders(for request: inout URLRequest) {
        if request.value(forHTTPHeaderField: MHBHTTPHeader.traceparent) == nil {
            request.setValue(Self.generateTraceparent(), forHTTPHeaderField: MHBHTTPHeader.traceparent)
        }
        if request.value(forHTTPHeaderField: MHBHTTPHeader.requestID) == nil {
            request.setValue(UUID().uuidString, forHTTPHeaderField: MHBHTTPHeader.requestID)
        }
    }

    private func instrumentIdempotencyHeader(for request: inout URLRequest) {
        let method = request.httpMethod?.uppercased() ?? "GET"
        guard ["POST", "PATCH", "DELETE"].contains(method),
              request.value(forHTTPHeaderField: MHBHTTPHeader.idempotencyKey) == nil else {
            return
        }
        request.setValue(UUID().uuidString, forHTTPHeaderField: MHBHTTPHeader.idempotencyKey)
    }

    private static func generateTraceparent() -> String {
        let traceID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let spanID = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)).lowercased()
        return "00-\(traceID)-\(spanID)-01"
    }
}

private extension MHBAPIError {
    var shouldAttemptTokenRefresh: Bool {
        guard case .business(let code, _, let statusCode) = self else {
            return false
        }
        return statusCode == 401 && [
            "auth.session_expired",
            "auth.token_invalid"
        ].contains(code)
    }
}

private struct MHBHTTPRetryableError: Error {
    let response: HTTPURLResponse
    let data: Data
}
