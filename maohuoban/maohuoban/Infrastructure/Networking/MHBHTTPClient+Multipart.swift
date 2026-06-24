import Foundation
import MaohuobanDiagnostics

// MHBHTTPClient multipart 请求支持
// 核心职责：
// - 构造 multipart/form-data 请求体
// - 支持单文件、多文件和上传进度回调
extension MHBHTTPClient {
    func postMultipart<ResponseBody: Decodable>(
        path: String,
        file: MHBMultipartFile,
        fields: [String: String] = [:],
        headers: [String: String] = [:],
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
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
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
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
        let fileBytes = files.reduce(0) { $0 + $1.data.count }
        await Diagnostics.track(
            "network.multipart.body_built",
            properties: [
                "issue_tag": .string(path.contains("/api/v1/profile/me/") ? "ProfileAvatarUpload" : ""),
                "path": .string(path),
                "file_count": .int(files.count),
                "file_bytes": .int(fileBytes),
                "body_bytes": .int(body.count),
                "field_count": .int(fields.count),
                "mime_types": .array(files.map { .string($0.mimeType) }),
                "file_names": .array(files.map { .string($0.fileName) })
            ]
        )

        return try await sendUpload(request, body: body, onUploadProgress: onUploadProgress)
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

    func sendUpload<ResponseBody: Decodable>(
        _ request: URLRequest,
        body: Data,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<ResponseBody> {
        var uploadRequest = request
        uploadRequest.httpBody = nil
        try prepareRequest(&uploadRequest)

        let delegate = MHBUploadProgressDelegate(onUploadProgress: onUploadProgress)
        let uploadSession = URLSession(
            configuration: session.configuration,
            delegate: delegate,
            delegateQueue: nil
        )

        let startedAt = Date()
        let requestPath = uploadRequest.url?.path ?? ""
        await Diagnostics.track(
            "network.multipart.upload_task_started",
            properties: [
                "issue_tag": .string(requestPath.contains("/api/v1/profile/me/") ? "ProfileAvatarUpload" : ""),
                "path": .string(requestPath),
                "body_bytes": .int(body.count),
                "request_id": .string(uploadRequest.value(forHTTPHeaderField: MHBHTTPHeader.requestID) ?? ""),
                "has_authorization": .bool(uploadRequest.value(forHTTPHeaderField: MHBHTTPHeader.authorization) != nil),
                "content_type": .string(uploadRequest.value(forHTTPHeaderField: "Content-Type") ?? "")
            ]
        )
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
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            await Diagnostics.track(
                "network.multipart.upload_task_completed",
                properties: [
                    "issue_tag": .string(requestPath.contains("/api/v1/profile/me/") ? "ProfileAvatarUpload" : ""),
                    "path": .string(requestPath),
                    "status_code": .int(statusCode),
                    "body_bytes": .int(body.count),
                    "response_bytes": .int(data.count),
                    "duration_ms": .int(elapsedMs),
                    "request_id": .string(uploadRequest.value(forHTTPHeaderField: MHBHTTPHeader.requestID) ?? "")
                ]
            )
        case .failure(let error):
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
            await Diagnostics.track(
                "network.multipart.upload_task_failed",
                properties: [
                    "issue_tag": .string(requestPath.contains("/api/v1/profile/me/") ? "ProfileAvatarUpload" : ""),
                    "path": .string(requestPath),
                    "error_kind": .string(error.diagnosticsSummary),
                    "body_bytes": .int(body.count),
                    "duration_ms": .int(elapsedMs),
                    "request_id": .string(uploadRequest.value(forHTTPHeaderField: MHBHTTPHeader.requestID) ?? "")
                ]
            )
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
}

// MHBUploadProgressDelegate 上传进度代理
// 核心职责：
// - 接收 URLSession 字节级上传回调
// - 将上传百分比回传给调用方
private final class MHBUploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let onUploadProgress: @MainActor @Sendable (Double) -> Void

    init(onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void) {
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
