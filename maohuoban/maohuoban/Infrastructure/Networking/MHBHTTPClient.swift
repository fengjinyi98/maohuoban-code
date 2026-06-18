import Foundation

// MHBMultipartFile multipart 文件字段
// 核心职责：
// - 承载 multipart 文件 part 的字段名、文件名、MIME 和二进制内容
// - 为 HTTP 客户端生成标准 form-data body 提供稳定输入
struct MHBMultipartFile: Equatable {
    let fieldName: String
    let fileName: String
    let mimeType: String
    let data: Data
}

// MHBHTTPClient 后端 HTTP 客户端
// 核心职责：
// - 统一发起 JSON 和 multipart 请求并解析后端标准响应
// - 将后端 code/message 转为可展示错误
// - 默认使用 Mac 局域网 IP 访问开发后端，方便真机联调
struct MHBHTTPClient {
    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL = MHBBackendEndpoint.localDevelopmentBaseURL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody,
        headers: [String: String] = [:]
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        try await sendJSON(method: "POST", path: path, body: body, headers: headers)
    }

    func postMultipart<ResponseBody: Decodable>(
        path: String,
        file: MHBMultipartFile,
        fields: [String: String] = [:],
        headers: [String: String] = [:],
        onUploadProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        try await postMultipart(
            path: path,
            files: [file],
            fields: fields,
            headers: headers,
            onUploadProgress: onUploadProgress
        )
    }

    func postMultipart<ResponseBody: Decodable>(
        path: String,
        files: [MHBMultipartFile],
        fields: [String: String] = [:],
        headers: [String: String] = [:],
        onUploadProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        let boundary = "maohuoban-\(UUID().uuidString)"
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        let body = multipartBody(boundary: boundary, files: files, fields: fields)
        request.httpBody = body

        guard let onUploadProgress else {
            return try await send(request)
        }

        return try await sendUpload(request, body: body, onUploadProgress: onUploadProgress)
    }

    func patch<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody,
        headers: [String: String] = [:]
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        try await sendJSON(method: "PATCH", path: path, body: body, headers: headers)
    }

    func delete<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody,
        headers: [String: String] = [:]
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        try await sendJSON(method: "DELETE", path: path, body: body, headers: headers)
    }

    private func sendJSON<RequestBody: Encodable, ResponseBody: Decodable>(
        method: String,
        path: String,
        body: RequestBody,
        headers: [String: String]
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw .decoding(error.localizedDescription)
        }

        return try await send(request)
    }

    private func multipartBody(
        boundary: String,
        file: MHBMultipartFile,
        fields: [String: String]
    ) -> Data {
        multipartBody(boundary: boundary, files: [file], fields: fields)
    }

    private func multipartBody(
        boundary: String,
        files: [MHBMultipartFile],
        fields: [String: String]
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        for file in files {
            body.append("--\(boundary)\(lineBreak)")
            body.append(
                "Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\(lineBreak)"
            )
            body.append("Content-Type: \(file.mimeType)\(lineBreak)\(lineBreak)")
            body.append(file.data)
            body.append(lineBreak)
        }

        for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)")
            body.append(value)
            body.append(lineBreak)
        }

        body.append("--\(boundary)--\(lineBreak)")
        return body
    }

    func get<ResponseBody: Decodable>(
        path: String,
        headers: [String: String] = [:]
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        return try await send(request)
    }

    func get<ResponseBody: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        headers: [String: String] = [:]
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        let basePathURL = baseURL.appending(path: path)
        guard var components = URLComponents(url: basePathURL, resolvingAgainstBaseURL: false) else {
            throw .invalidResponse
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw .invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        return try await send(request)
    }

    private func send<ResponseBody: Decodable>(
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

    private func sendUpload<ResponseBody: Decodable>(
        _ request: URLRequest,
        body: Data,
        onUploadProgress: @escaping @MainActor (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        var uploadRequest = request
        uploadRequest.httpBody = nil
        instrumentTraceHeaders(for: &uploadRequest)

        let delegate = MHBUploadProgressDelegate(onUploadProgress: onUploadProgress)
        let uploadSession = URLSession(
            configuration: session.configuration,
            delegate: delegate,
            delegateQueue: nil
        )

        let startedAt = Date()
        let result: Result<(Data, URLResponse), MHBAPIError> = await withCheckedContinuation { continuation in
            let task = uploadSession.uploadTask(with: uploadRequest, from: body) { data, response, error in
                uploadSession.finishTasksAndInvalidate()
                if let error {
                    continuation.resume(returning: .failure(.transport(error.localizedDescription)))
                    return
                }
                guard let data, let response else {
                    continuation.resume(returning: .failure(.invalidResponse))
                    return
                }
                continuation.resume(returning: .success((data, response)))
            }
            task.resume()
        }

        let data: Data
        let response: URLResponse
        switch result {
        case .success(let value):
            (data, response) = value
        case .failure(let error):
            await recordNetworkSummary(
                request: uploadRequest,
                response: nil,
                responseData: nil,
                requestBodyBytes: body.count,
                startedAt: startedAt,
                error: error.diagnosticsSummary
            )
            throw error
        }

        return try await decodeResponse(
            data: data,
            response: response,
            request: uploadRequest,
            requestBodyBytes: body.count,
            startedAt: startedAt
        )
    }

    private func decodeResponse<ResponseBody: Decodable>(
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

    private func instrumentTraceHeaders(for request: inout URLRequest) {
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

// MHBUploadProgressDelegate 上传进度代理
// 核心职责：
// - 接收 URLSession 字节级上传回调
// - 将上传百分比回传给调用方
private final class MHBUploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let onUploadProgress: @MainActor (Double) -> Void

    init(onUploadProgress: @escaping @MainActor (Double) -> Void) {
        self.onUploadProgress = onUploadProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else {
            return
        }
        let progress = min(max(Double(totalBytesSent) / Double(totalBytesExpectedToSend), 0), 1)
        Task { @MainActor in
            onUploadProgress(progress)
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
